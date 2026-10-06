"""AI servisi ve uçlarının testleri.

Gerçek Ollama sunucusuna ihtiyaç duymamak için `httpx.MockTransport`
kullanılıyor; böylece gönderilen isteğin biçimi ve hata eşlemeleri de
doğrulanabiliyor.
"""

from __future__ import annotations

import json

import httpx
import pytest
from httpx import AsyncClient

from app.core.config import settings
from app.core.exceptions import (
    AiModelMissing,
    AiServiceError,
    AiTimeout,
    AiUnavailable,
)
from app.main import app
from app.services.ai_service import SYSTEM_PROMPT, OllamaAiService, get_ai_service

ASK_URL = "/api/v1/ai/ask"
AI_HEALTH_URL = "/api/v1/ai/health"

CHAT_REPLY = {
    "model": "llama3",
    "message": {
        "role": "assistant",
        "content": "Alternatör, motor çalışırken elektrik üretip aküyü şarj eder.",
    },
    "done": True,
    "total_duration": 1_500_000_000,  # 1.5 saniye, nanosaniye cinsinden
}


def _service_with(handler) -> OllamaAiService:
    """Verilen işleyiciyle sahte bir Ollama'ya bağlı servis üretir."""
    client = httpx.AsyncClient(
        transport=httpx.MockTransport(handler),
        base_url=settings.ollama_base_url,
    )
    return OllamaAiService(client=client)


class TestOllamaRequestShape:
    async def test_request_targets_chat_endpoint_with_system_prompt(self) -> None:
        captured: dict[str, object] = {}

        def handler(request: httpx.Request) -> httpx.Response:
            captured["url"] = str(request.url)
            captured["body"] = json.loads(request.content)
            return httpx.Response(200, json=CHAT_REPLY)

        service = _service_with(handler)
        answer = await service.ask("Alternatör nedir?")

        assert captured["url"].endswith("/api/chat")
        body = captured["body"]
        assert body["model"] == settings.ollama_model
        assert body["stream"] is False
        assert body["options"]["temperature"] == settings.ollama_temperature
        assert body["messages"][0] == {"role": "system", "content": SYSTEM_PROMPT}
        assert body["messages"][1]["content"] == "Alternatör nedir?"
        # Görsel yoksa `images` alanı hiç gönderilmez.
        assert "images" not in body["messages"][1]

        assert answer.answer.startswith("Alternatör")
        assert answer.duration_ms == 1500

    async def test_context_is_prepended_to_question(self) -> None:
        captured: dict[str, object] = {}

        def handler(request: httpx.Request) -> httpx.Response:
            captured["body"] = json.loads(request.content)
            return httpx.Response(200, json=CHAT_REPLY)

        service = _service_with(handler)
        await service.ask("Bunu açıkla", context="Motor ve Araç Tekniği")

        content = captured["body"]["messages"][1]["content"]
        assert "Motor ve Araç Tekniği" in content
        assert "Bunu açıkla" in content

    async def test_images_switch_to_vision_model(self) -> None:
        captured: dict[str, object] = {}

        def handler(request: httpx.Request) -> httpx.Response:
            captured["body"] = json.loads(request.content)
            return httpx.Response(200, json=CHAT_REPLY)

        service = _service_with(handler)
        await service.ask("Bu parça nedir?", images=["QUJD"])

        body = captured["body"]
        # Llama 3 görsel anlamadığı için otomatik olarak görme modeline geçilir.
        assert body["model"] == settings.ollama_vision_model
        assert body["messages"][1]["images"] == ["QUJD"]

    async def test_explicit_model_overrides_auto_selection(self) -> None:
        captured: dict[str, object] = {}

        def handler(request: httpx.Request) -> httpx.Response:
            captured["body"] = json.loads(request.content)
            return httpx.Response(200, json=CHAT_REPLY)

        service = _service_with(handler)
        await service.ask("Bu parça nedir?", images=["QUJD"], model="llama3.2-vision")

        assert captured["body"]["model"] == "llama3.2-vision"


class TestOllamaErrorMapping:
    async def test_connection_error_becomes_unavailable(self) -> None:
        def handler(request: httpx.Request) -> httpx.Response:
            raise httpx.ConnectError("bağlantı reddedildi", request=request)

        service = _service_with(handler)

        with pytest.raises(AiUnavailable):
            await service.ask("Alternatör nedir?")

    async def test_timeout_becomes_ai_timeout(self) -> None:
        def handler(request: httpx.Request) -> httpx.Response:
            raise httpx.ReadTimeout("çok uzun sürdü", request=request)

        service = _service_with(handler)

        with pytest.raises(AiTimeout):
            await service.ask("Alternatör nedir?")

    async def test_missing_model_gives_actionable_message(self) -> None:
        def handler(request: httpx.Request) -> httpx.Response:
            return httpx.Response(404, json={"error": "model 'llama3' not found"})

        service = _service_with(handler)

        with pytest.raises(AiModelMissing) as error:
            await service.ask("Alternatör nedir?")

        assert "ollama pull llama3" in error.value.detail

    async def test_server_error_becomes_service_error(self) -> None:
        def handler(request: httpx.Request) -> httpx.Response:
            return httpx.Response(500, text="bozuldu")

        service = _service_with(handler)

        with pytest.raises(AiServiceError):
            await service.ask("Alternatör nedir?")

    async def test_empty_answer_is_rejected(self) -> None:
        def handler(request: httpx.Request) -> httpx.Response:
            return httpx.Response(200, json={"message": {"content": "   "}})

        service = _service_with(handler)

        with pytest.raises(AiServiceError):
            await service.ask("Alternatör nedir?")


class TestOllamaHealth:
    async def test_lists_installed_models(self) -> None:
        def handler(request: httpx.Request) -> httpx.Response:
            assert str(request.url).endswith("/api/tags")
            return httpx.Response(
                200,
                json={"models": [{"name": "llama3:latest"}, {"name": "llava:7b"}]},
            )

        service = _service_with(handler)
        health = await service.health()

        assert health.available is True
        assert health.installed_models == ["llama3:latest", "llava:7b"]

    async def test_unreachable_server_is_reported_not_raised(self) -> None:
        def handler(request: httpx.Request) -> httpx.Response:
            raise httpx.ConnectError("kapalı", request=request)

        service = _service_with(handler)
        health = await service.health()

        assert health.available is False
        assert "bağlanılamadı" in (health.detail or "")


class TestAiEndpoints:
    @staticmethod
    def _override(handler) -> None:
        app.dependency_overrides[get_ai_service] = lambda: _service_with(handler)

    def teardown_method(self) -> None:
        app.dependency_overrides.pop(get_ai_service, None)

    async def test_ask_requires_authentication(self, client: AsyncClient) -> None:
        response = await client.post(ASK_URL, json={"question": "Alternatör nedir?"})

        assert response.status_code == 401

    async def test_ask_requires_ai_pro_package(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
    ) -> None:
        self._override(lambda request: httpx.Response(200, json=CHAT_REPLY))

        response = await client.post(
            ASK_URL,
            json={"question": "Alternatör nedir?"},
            headers=auth_headers,
        )

        assert response.status_code == 403
        assert response.json()["error_code"] == "subscription_required"

    async def test_ai_pro_user_gets_answer(
        self,
        client: AsyncClient,
        ai_pro_headers: dict[str, str],
    ) -> None:
        self._override(lambda request: httpx.Response(200, json=CHAT_REPLY))

        response = await client.post(
            ASK_URL,
            json={"question": "Alternatör nedir?"},
            headers=ai_pro_headers,
        )

        assert response.status_code == 200
        body = response.json()
        assert "aküyü şarj" in body["answer"]
        assert body["model"] == "llama3"
        assert body["duration_ms"] == 1500

    async def test_ollama_down_returns_503(
        self,
        client: AsyncClient,
        ai_pro_headers: dict[str, str],
    ) -> None:
        def handler(request: httpx.Request) -> httpx.Response:
            raise httpx.ConnectError("kapalı", request=request)

        self._override(handler)

        response = await client.post(
            ASK_URL,
            json={"question": "Alternatör nedir?"},
            headers=ai_pro_headers,
        )

        assert response.status_code == 503
        assert response.json()["error_code"] == "ai_unavailable"

    async def test_empty_question_is_rejected(
        self,
        client: AsyncClient,
        ai_pro_headers: dict[str, str],
    ) -> None:
        response = await client.post(
            ASK_URL,
            json={"question": ""},
            headers=ai_pro_headers,
        )

        assert response.status_code == 422

    async def test_health_endpoint_reports_model_readiness(
        self,
        client: AsyncClient,
    ) -> None:
        def handler(request: httpx.Request) -> httpx.Response:
            return httpx.Response(200, json={"models": [{"name": "llama3:latest"}]})

        self._override(handler)

        response = await client.get(AI_HEALTH_URL)

        assert response.status_code == 200
        body = response.json()
        assert body["available"] is True
        # Ayarda "llama3" yazıyor, Ollama "llama3:latest" bildiriyor: etiketsiz
        # karşılaştırma sayesinde hazır kabul edilmeli.
        assert body["model_ready"] is True
        assert body["configured_model"] == settings.ollama_model
