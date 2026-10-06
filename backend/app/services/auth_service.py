"""Kayıt, giriş ve kullanıcı sorgulama işleri."""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import EmailAlreadyRegistered, InvalidCredentials
from app.core.security import (
    hash_password,
    verify_password,
    waste_password_cycle,
)
from app.models.user import SubscriptionStatus, User


def normalize_email(email: str) -> str:
    """E-postayı kimlik olarak kullanılabilir hâle getirir."""
    return email.strip().lower()


async def get_user_by_email(session: AsyncSession, email: str) -> User | None:
    result = await session.execute(
        select(User).where(User.email == normalize_email(email))
    )
    return result.scalar_one_or_none()


async def get_user_by_id(session: AsyncSession, user_id: int) -> User | None:
    return await session.get(User, user_id)


async def register_user(
    session: AsyncSession,
    *,
    email: str,
    password: str,
) -> User:
    """Yeni kullanıcı oluşturur.

    E-posta zaten kayıtlıysa `EmailAlreadyRegistered` fırlatır.
    """
    normalized = normalize_email(email)

    if await get_user_by_email(session, normalized) is not None:
        raise EmailAlreadyRegistered

    user = User(
        email=normalized,
        password_hash=hash_password(password),
        subscription_status=SubscriptionStatus.free,
    )
    session.add(user)

    try:
        await session.commit()
    except IntegrityError as error:
        # İki istek aynı anda geldiğinde ön kontrol yetmez; benzersizlik
        # kısıtı son sözü söyler.
        await session.rollback()
        raise EmailAlreadyRegistered from error

    await session.refresh(user)
    return user


async def authenticate_user(
    session: AsyncSession,
    *,
    email: str,
    password: str,
) -> User:
    """E-posta ve şifreyi doğrular.

    Hesabın var olup olmadığının yanıt süresinden anlaşılmaması için
    kullanıcı bulunamadığında da bir bcrypt doğrulaması yapılır.
    """
    user = await get_user_by_email(session, email)

    if user is None:
        waste_password_cycle()
        raise InvalidCredentials

    if not verify_password(password, user.password_hash):
        raise InvalidCredentials

    return user


async def update_subscription(
    session: AsyncSession,
    user: User,
    status: SubscriptionStatus,
) -> User:
    """Kullanıcının paket durumunu günceller."""
    user.subscription_status = status
    await session.commit()
    await session.refresh(user)
    return user
