"""Uygulama ayarları.

Tüm yapılandırma ortam değişkenlerinden (veya `.env` dosyasından) okunur;
kodun içinde sabit URL/anahtar bulunmaz.
"""

from __future__ import annotations

import secrets
from functools import lru_cache
from typing import Literal

from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

# Geliştirme kolaylığı için üretilen yer tutucu anahtar. Üretimde bu değerin
# kullanılması `Settings` doğrulamasında engellenir.
DEV_JWT_SECRET = "dev-only-insecure-secret-change-me"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
    )

    # ----------------------------------------------------------- Uygulama
    app_name: str = "Stop! AI Ehliyet Kocu API"
    app_version: str = "0.1.0"
    environment: Literal["development", "staging", "production"] = "development"
    debug: bool = True
    api_v1_prefix: str = "/api/v1"

    # --------------------------------------------------------- Veritabanı
    # Örnek: sqlite+aiosqlite:///./test.db
    # PostgreSQL: postgresql+asyncpg://kullanici:sifre@localhost:5432/stopkoc
    database_url: str = "sqlite+aiosqlite:///./test.db"
    db_echo: bool = False
    db_pool_size: int = 5
    db_max_overflow: int = 10

    # ------------------------------------------------------------ Güvenlik
    jwt_secret_key: str = DEV_JWT_SECRET
    jwt_algorithm: str = "HS256"

    # Mobil uygulamanın sık sık yeniden giriş istememesi için uzun ömürlü.
    access_token_expire_minutes: int = Field(default=60 * 24 * 7, ge=5)

    # bcrypt maliyet katsayısı. Yükseltmek girişleri yavaşlatır ama kaba
    # kuvvet saldırısını pahalılaştırır.
    bcrypt_rounds: int = Field(default=12, ge=4, le=16)

    # Virgülle ayrılmış liste; `*` tüm kaynaklara izin verir.
    cors_origins: str = "*"

    # --------------------------------------------------- Ollama / Llama 3
    ollama_base_url: str = "http://localhost:11434"

    # Metin soruları için kullanılacak model.
    ollama_model: str = "llama3"

    # Görsel içeren sorgular için model. Llama 3 görsel anlamadığı için
    # fotoğraf gönderildiğinde otomatik olarak buna geçilir.
    ollama_vision_model: str = "llava"

    ollama_timeout_seconds: float = Field(default=90.0, gt=0)
    ollama_temperature: float = Field(default=0.3, ge=0, le=2)

    # Yanıt uzunluğu sınırı (Ollama `num_predict`).
    ollama_max_tokens: int = Field(default=512, ge=32)

    # AI uçlarının yalnızca AI Pro paketi olan kullanıcılara açılması.
    # Mobil uygulamadaki 299 TL paketinin sunucu tarafı karşılığı.
    ai_requires_subscription: bool = True

    @property
    def cors_origin_list(self) -> list[str]:
        """`cors_origins` ayarını FastAPI'nin beklediği listeye çevirir."""
        return [
            origin.strip()
            for origin in self.cors_origins.split(",")
            if origin.strip()
        ]

    @property
    def is_production(self) -> bool:
        return self.environment == "production"

    @model_validator(mode="after")
    def _guard_production_secrets(self) -> Settings:
        """Üretimde güvensiz varsayılanlarla açılmayı engeller."""
        if not self.is_production:
            return self

        if self.jwt_secret_key == DEV_JWT_SECRET or len(self.jwt_secret_key) < 32:
            raise ValueError(
                "Üretim ortamında JWT_SECRET_KEY en az 32 karakterlik özel bir "
                "değer olmalı. Örnek üretmek için: "
                f"python -c \"import secrets; print(secrets.token_urlsafe(48))\" "
                f"(ör. {secrets.token_urlsafe(48)[:12]}...)"
            )

        if self.cors_origin_list == ["*"]:
            raise ValueError(
                "Üretim ortamında CORS_ORIGINS açıkça belirtilmeli; '*' "
                "kullanılamaz."
            )

        return self


@lru_cache
def get_settings() -> Settings:
    """Ayarları bir kez okuyup önbelleğe alır."""
    return Settings()


settings = get_settings()
