"""AI koç istek/yanıt şemaları."""

from __future__ import annotations

from pydantic import BaseModel, Field

MAX_QUESTION_LENGTH = 2000
MAX_IMAGES = 4


class AiAskRequest(BaseModel):
    """Mobil uygulamadan gelen soru."""

    question: str = Field(
        min_length=1,
        max_length=MAX_QUESTION_LENGTH,
        examples=["Alternatör nedir?"],
    )

    # Kullanıcının o anki konusu/yanlış yaptığı kategori gibi ek bilgi.
    context: str | None = Field(default=None, max_length=MAX_QUESTION_LENGTH)

    # Araç parçası fotoğrafları, base64 kodlu. Görsel gönderildiğinde
    # servis otomatik olarak görme yeteneği olan modele geçer.
    images: list[str] | None = Field(
        default=None,
        max_length=MAX_IMAGES,
        description="base64 kodlu görseller (data URL öneki olmadan).",
    )

    # Belirli bir modeli zorlamak için (ör. "llama3:8b").
    model: str | None = Field(default=None, max_length=120)


class AiAskResponse(BaseModel):
    answer: str
    model: str = Field(description="Yanıtı üreten Ollama modeli.")
    duration_ms: int = Field(description="Modelin yanıt üretme süresi.")


class AiHealthResponse(BaseModel):
    """Ollama sunucusunun durumu; mobil tarafta tanı için kullanışlı."""

    available: bool
    base_url: str
    configured_model: str
    configured_vision_model: str
    installed_models: list[str]
    model_ready: bool = Field(
        description="Yapılandırılan metin modeli Ollama'da yüklü mü."
    )
    detail: str | None = None
