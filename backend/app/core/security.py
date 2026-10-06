"""Şifre hashleme ve JWT üretimi/doğrulaması."""

from __future__ import annotations

import base64
import hashlib
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

import bcrypt
import jwt

from app.core.config import settings
from app.core.exceptions import InvalidToken, TokenExpired

TOKEN_TYPE = "access"  # noqa: S105 - token tipi etiketi, gizli değil

# Şifre doğrulanamadığında da aynı süre harcanması için kullanılan sahte özet.
# Kullanıcı yoksa bunu doğrulayarak "hesap var mı?" bilgisinin yanıt
# süresinden okunmasını engelliyoruz.
_DUMMY_HASH = "$2b$12$C6UzMDM.H6dfI/f/IKcEe.aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"


def _prehash(password: str) -> bytes:
    """Şifreyi bcrypt'e vermeden önce sabit uzunluğa indirir.

    bcrypt girdiyi 72 baytla sınırlar; uzun şifrelerde sessizce kırpmak
    yerine önce SHA-256 özeti alıp base64'lüyoruz (Django'nun
    `BCryptSHA256PasswordHasher`'ı ile aynı yaklaşım). Böylece şifre
    uzunluğu sınırsız olur ve NUL bayt sorunu yaşanmaz.
    """
    digest = hashlib.sha256(password.encode("utf-8")).digest()
    return base64.b64encode(digest)


def hash_password(password: str) -> str:
    """Şifreyi rastgele salt ile hashler."""
    salt = bcrypt.gensalt(rounds=settings.bcrypt_rounds)
    return bcrypt.hashpw(_prehash(password), salt).decode("ascii")


def verify_password(password: str, password_hash: str) -> bool:
    """Girilen şifrenin kayıtlı özetle eşleşip eşleşmediğini söyler."""
    try:
        return bcrypt.checkpw(_prehash(password), password_hash.encode("ascii"))
    except (ValueError, TypeError):
        # Bozuk/eksik özet kaydı: çökmek yerine doğrulamayı reddet.
        return False


def waste_password_cycle() -> None:
    """Kullanıcı bulunamadığında bcrypt maliyetini yine de harcar."""
    verify_password("stopkoc-dummy-password", _DUMMY_HASH)


@dataclass(frozen=True, slots=True)
class AccessToken:
    token: str
    expires_in: int
    """Saniye cinsinden kalan ömür; mobil istemci yenilemeyi buna göre planlar."""

    expires_at: datetime


@dataclass(frozen=True, slots=True)
class TokenPayload:
    user_id: int
    expires_at: datetime
    token_id: str


def create_access_token(
    user_id: int,
    *,
    expires_delta: timedelta | None = None,
) -> AccessToken:
    """Kullanıcı için imzalı bir erişim anahtarı üretir."""
    lifetime = expires_delta or timedelta(
        minutes=settings.access_token_expire_minutes
    )
    issued_at = datetime.now(UTC)
    expires_at = issued_at + lifetime

    payload = {
        # JWT standardı `sub` alanının metin olmasını ister; PyJWT 2.10+
        # bunu doğrularken zorunlu tutuyor.
        "sub": str(user_id),
        "iat": int(issued_at.timestamp()),
        "exp": int(expires_at.timestamp()),
        "jti": uuid.uuid4().hex,
        "type": TOKEN_TYPE,
    }

    token = jwt.encode(
        payload,
        settings.jwt_secret_key,
        algorithm=settings.jwt_algorithm,
    )

    return AccessToken(
        token=token,
        expires_in=int(lifetime.total_seconds()),
        expires_at=expires_at,
    )


def decode_access_token(token: str) -> TokenPayload:
    """Anahtarı doğrular ve içindeki kullanıcı kimliğini döner.

    Geçersiz veya süresi geçmiş anahtarlarda `AppError` türevi fırlatır.
    """
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret_key,
            algorithms=[settings.jwt_algorithm],
            options={"require": ["exp", "sub"]},
        )
    except jwt.ExpiredSignatureError as error:
        raise TokenExpired from error
    except jwt.InvalidTokenError as error:
        raise InvalidToken from error

    if payload.get("type") != TOKEN_TYPE:
        raise InvalidToken("Anahtar tipi bu işlem için uygun değil.")

    subject = payload.get("sub")
    try:
        user_id = int(subject)
    except (TypeError, ValueError) as error:
        raise InvalidToken("Anahtar içindeki kullanıcı kimliği okunamadı.") from error

    return TokenPayload(
        user_id=user_id,
        expires_at=datetime.fromtimestamp(payload["exp"], tz=UTC),
        token_id=str(payload.get("jti", "")),
    )
