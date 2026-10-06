"""FastAPI uygulaması."""

from __future__ import annotations

import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text

from app.api.router import api_router
from app.core.config import settings
from app.core.database import SessionFactory, dispose_engine
from app.core.exceptions import AppError
from app.services.ai_service import init_ai_service, shutdown_ai_service

logging.basicConfig(
    level=logging.DEBUG if settings.debug else logging.INFO,
    format="%(asctime)s %(levelname)-8s %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    """Paylaşılan kaynakları açar ve kapanışta temizler."""
    init_ai_service()
    logger.info(
        "%s başlatıldı (ortam=%s, Ollama=%s, model=%s)",
        settings.app_name,
        settings.environment,
        settings.ollama_base_url,
        settings.ollama_model,
    )

    try:
        yield
    finally:
        await shutdown_ai_service()
        await dispose_engine()
        logger.info("Kapatma tamamlandı.")


app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    summary="Stop! AI Ehliyet Koçu mobil uygulamasının sunucu tarafı.",
    description=(
        "Kimlik doğrulama (JWT), test sonuçları ve yerel Ollama (Llama 3) "
        "üzerinden çalışan AI koç uçları."
    ),
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(AppError)
async def handle_app_error(_: Request, error: AppError) -> JSONResponse:
    """Tüm iş kuralı hatalarını tek tip gövdeye çevirir.

    İstemci `error_code` alanına bakarak mesajı kendi diliyle
    gösterebilir; `detail` zaten kullanıcıya gösterilebilir Türkçe metin.
    """
    headers = {}
    if error.status_code == status.HTTP_401_UNAUTHORIZED:
        headers["WWW-Authenticate"] = "Bearer"

    return JSONResponse(
        status_code=error.status_code,
        content={"detail": error.detail, "error_code": error.error_code},
        headers=headers,
    )


@app.get("/health", tags=["health"], summary="Canlılık kontrolü")
async def health() -> dict[str, str]:
    """Bağımlılık kontrolü yapmaz; sadece sürecin ayakta olduğunu söyler."""
    return {
        "status": "ok",
        "app": settings.app_name,
        "version": settings.app_version,
        "environment": settings.environment,
    }


@app.get("/health/ready", tags=["health"], summary="Veritabanı hazırlık kontrolü")
async def readiness() -> JSONResponse:
    """Veritabanına gerçekten bağlanabildiğimizi doğrular."""
    try:
        async with SessionFactory() as session:
            await session.execute(text("SELECT 1"))
    except Exception as error:  # noqa: BLE001 - durum bildirimi, yeniden fırlatma yok
        logger.warning("Hazırlık kontrolü başarısız: %s", error)
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"status": "unavailable", "database": "unreachable"},
        )

    return JSONResponse(content={"status": "ready", "database": "ok"})


app.include_router(api_router, prefix=settings.api_v1_prefix)
