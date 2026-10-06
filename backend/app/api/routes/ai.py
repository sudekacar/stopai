"""AI koç uçları (yerel Ollama / Llama 3)."""

from __future__ import annotations

import logging
from typing import Annotated

from fastapi import APIRouter, Depends

from app.api.deps import AiUser
from app.core.config import settings
from app.schemas.ai import AiAskRequest, AiAskResponse, AiHealthResponse
from app.services.ai_service import OllamaAiService, get_ai_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["ai"])

AiServiceDep = Annotated[OllamaAiService, Depends(get_ai_service)]


@router.post(
    "/ask",
    response_model=AiAskResponse,
    summary="AI koça soru sor (metin veya araç parçası fotoğrafı)",
    responses={
        403: {"description": "AI Pro paketi gerekli"},
        503: {"description": "Ollama çalışmıyor veya model yüklü değil"},
        504: {"description": "Model zaman aşımına uğradı"},
    },
)
async def ask(
    payload: AiAskRequest,
    user: AiUser,
    service: AiServiceDep,
) -> AiAskResponse:
    """Soruyu sunucuda çalışan Llama 3 modeline iletir.

    Görsel gönderildiğinde model otomatik olarak görme yeteneği olan
    modele (varsayılan `llava`) geçer; Llama 3 metin modeli fotoğrafı
    yorumlayamaz.
    """
    answer = await service.ask(
        payload.question,
        context=payload.context,
        images=payload.images,
        model=payload.model,
    )

    logger.info(
        "AI yanıtı üretildi: user_id=%s model=%s süre=%sms görsel=%s",
        user.id,
        answer.model,
        answer.duration_ms,
        len(payload.images or []),
    )

    return AiAskResponse(
        answer=answer.answer,
        model=answer.model,
        duration_ms=answer.duration_ms,
    )


@router.get(
    "/health",
    response_model=AiHealthResponse,
    summary="Ollama bağlantısını ve yüklü modelleri kontrol et",
)
async def ai_health(service: AiServiceDep) -> AiHealthResponse:
    """Tanı ucu: Ollama ayakta mı, yapılandırılan model yüklü mü.

    Hata fırlatmaz; durumu yanıt gövdesinde bildirir; böylece mobil
    tarafta "AI şu an kullanılamıyor" mesajı gösterilebilir.
    """
    health = await service.health()

    # Ollama model adlarını `llama3:latest` biçiminde döner; ayarda etiket
    # yazılmamış olabilir, bu yüzden etiketsiz karşılaştırma da yapılıyor.
    installed_bases = {name.split(":", 1)[0] for name in health.installed_models}
    configured = settings.ollama_model
    model_ready = (
        configured in health.installed_models
        or configured.split(":", 1)[0] in installed_bases
    )

    return AiHealthResponse(
        available=health.available,
        base_url=settings.ollama_base_url,
        configured_model=configured,
        configured_vision_model=settings.ollama_vision_model,
        installed_models=health.installed_models,
        model_ready=health.available and model_ready,
        detail=health.detail,
    )
