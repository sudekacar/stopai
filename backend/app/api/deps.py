"""Ortak FastAPI bağımlılıkları.

JWT doğrulaması burada tek bir yerde yapılır; korumalı her uç
`CurrentUser` bağımlılığını alarak güvenli hâle gelir.
"""

from __future__ import annotations

from typing import Annotated

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_session
from app.core.exceptions import (
    InvalidToken,
    NotAuthenticated,
    SubscriptionRequired,
)
from app.core.security import decode_access_token
from app.models.user import User
from app.services import auth_service

# `auto_error=False`: eksik başlığı kendimiz ele alıp tek tip hata gövdesi
# döndürmek için.
bearer_scheme = HTTPBearer(
    auto_error=False,
    scheme_name="JWT",
    description="Giriş yanıtındaki access_token değerini `Bearer <token>` "
    "olarak gönderin.",
)

SessionDep = Annotated[AsyncSession, Depends(get_session)]


async def get_current_user(
    session: SessionDep,
    credentials: Annotated[
        HTTPAuthorizationCredentials | None, Depends(bearer_scheme)
    ] = None,
) -> User:
    """Authorization başlığındaki JWT'yi doğrulayıp kullanıcıyı getirir."""
    if credentials is None or not credentials.credentials:
        raise NotAuthenticated

    payload = decode_access_token(credentials.credentials)

    user = await auth_service.get_user_by_id(session, payload.user_id)
    if user is None:
        # Anahtar geçerli ama kullanıcı silinmiş: oturumu geçersiz say.
        raise InvalidToken("Anahtarın sahibi bulunamadı.")

    return user


CurrentUser = Annotated[User, Depends(get_current_user)]


async def require_ai_access(user: CurrentUser) -> User:
    """AI uçlarını AI Pro paketiyle sınırlar.

    Mobil uygulamada AI sekmesi 299 TL paketinin arkasında; aynı kuralı
    sunucuda da uyguluyoruz, yoksa istemci kontrolü atlanarak model
    ücretsiz kullanılabilir. Geliştirme sırasında
    `AI_REQUIRES_SUBSCRIPTION=false` ile kapatılabilir.
    """
    if not settings.ai_requires_subscription:
        return user

    if not user.subscription_status.unlocks_ai:
        raise SubscriptionRequired

    return user


AiUser = Annotated[User, Depends(require_ai_access)]
