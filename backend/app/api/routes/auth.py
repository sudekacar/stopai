"""Kayıt, giriş ve profil uçları."""

from __future__ import annotations

from fastapi import APIRouter, status

from app.api.deps import CurrentUser, SessionDep
from app.core.security import create_access_token
from app.models.user import User
from app.schemas.auth import LoginRequest, RegisterRequest, TokenResponse
from app.schemas.user import SubscriptionUpdate, UserRead
from app.services import auth_service

router = APIRouter(prefix="/auth", tags=["auth"])


def _token_response(user: User) -> TokenResponse:
    token = create_access_token(user.id)
    return TokenResponse(
        access_token=token.token,
        expires_in=token.expires_in,
        user=UserRead.model_validate(user),
    )


@router.post(
    "/register",
    response_model=TokenResponse,
    status_code=status.HTTP_201_CREATED,
    summary="E-posta ve şifre ile kayıt ol",
    responses={409: {"description": "E-posta zaten kayıtlı"}},
)
async def register(payload: RegisterRequest, session: SessionDep) -> TokenResponse:
    """Yeni hesap açar ve doğrudan oturum anahtarı döner.

    Kayıt sonrası ayrıca giriş yapmak gerekmez; mobil uygulama tek istekle
    ana test menüsüne geçebilir.
    """
    user = await auth_service.register_user(
        session,
        email=payload.email,
        password=payload.password,
    )
    return _token_response(user)


@router.post(
    "/login",
    response_model=TokenResponse,
    summary="E-posta ve şifre ile giriş yap",
    responses={401: {"description": "E-posta veya şifre hatalı"}},
)
async def login(payload: LoginRequest, session: SessionDep) -> TokenResponse:
    user = await auth_service.authenticate_user(
        session,
        email=payload.email,
        password=payload.password,
    )
    return _token_response(user)


@router.get(
    "/me",
    response_model=UserRead,
    summary="Oturumu açık kullanıcıyı getir",
)
async def read_me(user: CurrentUser) -> User:
    """Mobil uygulama açılışta anahtarın hâlâ geçerli olduğunu buradan anlar."""
    return user


@router.patch(
    "/me/subscription",
    response_model=UserRead,
    summary="Paket durumunu güncelle",
)
async def update_my_subscription(
    payload: SubscriptionUpdate,
    user: CurrentUser,
    session: SessionDep,
) -> User:
    """Satın alma sonrası paket durumunu kaydeder.

    Not: Bu uç şimdilik istemcinin bildirimine güvenir. Canlıya çıkmadan
    önce RevenueCat webhook'u ya da mağaza makbuzu doğrulaması eklenmeli.
    """
    return await auth_service.update_subscription(
        session,
        user,
        payload.subscription_status,
    )
