"""Kimlik doğrulama istek/yanıt şemaları."""

from __future__ import annotations

import re

from pydantic import BaseModel, EmailStr, Field, field_validator

from app.schemas.user import UserRead

# Mobil uygulamadaki `AuthValidators` ile aynı kural: en az 6 karakter,
# en az bir harf ve bir rakam. Sunucu tarafı istemciden daha gevşek
# olmamalı ama daha katı da olmamalı, yoksa uygulamada geçen şifre
# burada reddedilir.
MIN_PASSWORD_LENGTH = 6
MAX_PASSWORD_LENGTH = 128

_LETTER_PATTERN = re.compile(r"[^\W\d_]", re.UNICODE)
_DIGIT_PATTERN = re.compile(r"\d")


class _PasswordRules(BaseModel):
    password: str = Field(
        min_length=MIN_PASSWORD_LENGTH,
        max_length=MAX_PASSWORD_LENGTH,
        examples=["Sifre123"],
    )

    @field_validator("password")
    @classmethod
    def _check_complexity(cls, value: str) -> str:
        if not _LETTER_PATTERN.search(value):
            raise ValueError("Şifre en az bir harf içermeli.")
        if not _DIGIT_PATTERN.search(value):
            raise ValueError("Şifre en az bir rakam içermeli.")
        return value


class RegisterRequest(_PasswordRules):
    email: EmailStr = Field(examples=["surucu@stopkoc.com"])


class LoginRequest(BaseModel):
    email: EmailStr = Field(examples=["surucu@stopkoc.com"])

    # Girişte karmaşıklık kuralı uygulanmaz: kural sonradan değişse bile
    # eski kullanıcılar giriş yapabilmeli.
    password: str = Field(min_length=1, max_length=MAX_PASSWORD_LENGTH)


class TokenResponse(BaseModel):
    """Başarılı kayıt/girişte dönen JWT ve kullanıcı bilgisi."""

    access_token: str
    token_type: str = "bearer"
    expires_in: int = Field(description="Anahtarın saniye cinsinden ömrü.")
    user: UserRead
