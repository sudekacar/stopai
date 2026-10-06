"""Kullanıcı yanıt şemaları."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr

from app.models.user import SubscriptionStatus


class UserRead(BaseModel):
    """İstemciye dönen kullanıcı bilgisi. `password_hash` asla yer almaz."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    email: EmailStr
    subscription_status: SubscriptionStatus
    created_at: datetime


class SubscriptionUpdate(BaseModel):
    """Satın alma doğrulandıktan sonra paket durumunu güncellemek için.

    Gerçek akışta bu uç RevenueCat webhook'u veya mağaza makbuzu
    doğrulamasıyla korunacak; şimdilik kullanıcının kendi paketini
    bildirmesi için açık.
    """

    subscription_status: SubscriptionStatus
