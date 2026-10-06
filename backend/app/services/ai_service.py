"""Yerel Ollama (Llama 3) entegrasyonu.

Mobil uygulamadan gelen soru ve araç parçası fotoğrafları bu modül
üzerinden sunucuda çalışan Ollama'ya iletilir; yanıt sadeleştirilip
istemciye döner. Dışarıya veri çıkmaz: model aynı makinede
(`http://localhost:11434`) çalışır.

Kullanılan Ollama uçları:
- `POST /api/chat`  : sistem + kullanıcı mesajıyla yanıt üretir
- `GET  /api/tags`  : yüklü modelleri listeler (sağlık kontrolü)
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

import httpx

from app.core.config import Settings, settings
from app.core.exceptions import (
    AiModelMissing,
    AiServiceError,
    AiTimeout,
    AiUnavailable,
)

logger = logging.getLogger(__name__)

# Koçun kimliğini ve sınırlarını belirleyen yönerge. Model küçük olduğu
# için talimatlar kısa ve kesin tutuldu.
SYSTEM_PROMPT = """Sen "Stop! AI Ehliyet Koçu" uygulamasının yardımcısısın.
Türkiye'deki sürücü kursu müfredatına (trafik ve çevre bilgisi, ilk yardım,
motor ve araç tekniği, trafik adabı) göre cevap verirsin.

Kuralların:
- Her zaman Türkçe yanıt ver.
- Sade ve kısa anlat: en fazla 4 kısa paragraf ya da 6 madde.
- Sınavda çıkan kritik ayrımları vurgula (ör. marş motoru ile alternatörün
  görevlerinin karıştırılması).
- Emin olmadığın bir bilgiyi uydurma; bilmiyorsan bilmediğini söyle ve
  kullanıcıyı ilgili konuya yönlendir.
- Tıbbi veya hukuki tavsiye verme; ilk yardım sorularında yalnızca müfredattaki
  uygulamaları anlat.
- Fotoğraf verildiyse önce parçayı tanımla, sonra görevini ve arızalandığında
  görülen belirtileri açıkla."""


@dataclass(frozen=True, slots=True)
class AiAnswer:
    answer: str
    model: str
    duration_ms: int


@dataclass(frozen=True, slots=True)
class OllamaHealth:
    available: bool
    installed_models: list[str]
    detail: str | None = None


class OllamaAiService:
    """Ollama HTTP API'sinin ince bir sarmalayıcısı.

    `httpx.AsyncClient` dışarıdan verilebilir; testler bu sayede gerçek bir
    sunucuya ihtiyaç duymadan `MockTransport` ile çalışır.
    """

    def __init__(
        self,
        *,
        config: Settings | None = None,
        client: httpx.AsyncClient | None = None,
    ) -> None:
        self._settings = config or settings
        self._owns_client = client is None
        self._client = client or httpx.AsyncClient(
            base_url=self._settings.ollama_base_url,
            timeout=httpx.Timeout(self._settings.ollama_timeout_seconds),
        )

    # ------------------------------------------------------------ Genel API

    async def ask(
        self,
        question: str,
        *,
        context: str | None = None,
        images: list[str] | None = None,
        model: str | None = None,
    ) -> AiAnswer:
        """Soruyu modele iletir ve yanıtı döner.

        Görsel gönderildiğinde ve açık bir model belirtilmediğinde görme
        yeteneği olan modele geçilir; Llama 3 metin modeli fotoğrafı
        yorumlayamaz.
        """
        target_model = model or self._select_model(images)
        payload = self._build_chat_payload(
            question=question,
            context=context,
            images=images,
            model=target_model,
        )

        data = await self._post("/api/chat", payload, model=target_model)

        content = str(data.get("message", {}).get("content", "")).strip()
        if not content:
            raise AiServiceError("Model boş bir yanıt döndürdü.")

        # Ollama süreyi nanosaniye olarak bildirir.
        total_duration_ns = int(data.get("total_duration") or 0)

        return AiAnswer(
            answer=content,
            model=str(data.get("model") or target_model),
            duration_ms=total_duration_ns // 1_000_000,
        )

    async def health(self) -> OllamaHealth:
        """Ollama'ya ulaşılıp ulaşılamadığını ve yüklü modelleri bildirir.

        Bu uç tanı amaçlı olduğu için hata fırlatmaz; durumu veri olarak
        döner.
        """
        try:
            response = await self._client.get("/api/tags")
            response.raise_for_status()
        except httpx.TimeoutException:
            return OllamaHealth(False, [], "Ollama zaman aşımına uğradı.")
        except httpx.RequestError as error:
            return OllamaHealth(False, [], f"Ollama'ya bağlanılamadı: {error}")
        except httpx.HTTPStatusError as error:
            return OllamaHealth(
                False, [], f"Ollama {error.response.status_code} döndürdü."
            )

        models = response.json().get("models") or []
        names = [str(item.get("name", "")) for item in models if item.get("name")]
        return OllamaHealth(True, names)

    async def close(self) -> None:
        """Dışarıdan verilmeyen istemciyi kapatır."""
        if self._owns_client:
            await self._client.aclose()

    # --------------------------------------------------------- Yardımcılar

    def _select_model(self, images: list[str] | None) -> str:
        if images:
            return self._settings.ollama_vision_model
        return self._settings.ollama_model

    def _build_chat_payload(
        self,
        *,
        question: str,
        context: str | None,
        images: list[str] | None,
        model: str,
    ) -> dict[str, object]:
        user_message: dict[str, object] = {
            "role": "user",
            "content": self._compose_user_content(question, context),
        }

        if images:
            # Ollama görselleri mesajın `images` alanında base64 bekler.
            user_message["images"] = images

        return {
            "model": model,
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                user_message,
            ],
            # Tek parça yanıt: mobil istemci şimdilik akış tüketmiyor.
            "stream": False,
            "options": {
                "temperature": self._settings.ollama_temperature,
                "num_predict": self._settings.ollama_max_tokens,
            },
        }

    @staticmethod
    def _compose_user_content(question: str, context: str | None) -> str:
        question = question.strip()
        if not context:
            return question

        return (
            f"Öğrencinin çalıştığı konu / önceki bağlam: {context.strip()}\n\n"
            f"Sorusu: {question}"
        )

    async def _post(
        self,
        path: str,
        payload: dict[str, object],
        *,
        model: str,
    ) -> dict[str, object]:
        """Ollama'ya POST atar ve hataları uygulama hatalarına çevirir."""
        try:
            response = await self._client.post(path, json=payload)
            response.raise_for_status()
        except httpx.TimeoutException as error:
            logger.warning("Ollama zaman aşımı: %s", error)
            raise AiTimeout from error
        except httpx.RequestError as error:
            logger.warning("Ollama bağlantı hatası: %s", error)
            raise AiUnavailable from error
        except httpx.HTTPStatusError as error:
            raise self._map_status_error(error, model) from error

        try:
            data = response.json()
        except ValueError as error:
            raise AiServiceError("Ollama yanıtı okunamadı.") from error

        if not isinstance(data, dict):
            raise AiServiceError("Ollama beklenmeyen bir yanıt biçimi döndürdü.")

        return data

    @staticmethod
    def _map_status_error(
        error: httpx.HTTPStatusError,
        model: str,
    ) -> AiServiceError:
        status = error.response.status_code
        body = error.response.text[:300]

        # Model yüklü değilse Ollama 404 + "model ... not found" döner.
        if status == 404:
            logger.warning("Ollama modeli bulunamadı (%s): %s", model, body)
            return AiModelMissing(
                f"'{model}' modeli Ollama'da yüklü değil. "
                f"Sunucuda `ollama pull {model}` komutunu çalıştırın."
            )

        logger.error("Ollama %s döndürdü: %s", status, body)
        return AiServiceError(f"AI servisi {status} yanıtı döndürdü.")


# Uygulama ömrü boyunca paylaşılan tek örnek; `main.py` içindeki lifespan
# tarafından oluşturulup kapatılır.
_service: OllamaAiService | None = None


def init_ai_service(service: OllamaAiService | None = None) -> OllamaAiService:
    global _service  # noqa: PLW0603 - tek örnek bilinçli olarak modülde
    _service = service or OllamaAiService()
    return _service


async def shutdown_ai_service() -> None:
    global _service  # noqa: PLW0603
    if _service is not None:
        await _service.close()
        _service = None


def get_ai_service() -> OllamaAiService:
    """FastAPI bağımlılığı olarak kullanılan erişim noktası."""
    if _service is None:
        # Uygulama dışında (ör. betik) kullanıldığında da çalışsın.
        return init_ai_service()
    return _service
