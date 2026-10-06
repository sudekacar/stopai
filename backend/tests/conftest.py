"""Test altyapısı.

Testler PostgreSQL yerine bellek içi SQLite kullanır: şema aynı ORM
modellerinden üretildiği için tablo/kısıt tanımları yine doğrulanır, ama
çalıştırmak için ayakta bir veritabanı sunucusu gerekmez.
"""

from __future__ import annotations

from collections.abc import AsyncIterator

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.core.database import get_session
from app.main import app
from app.models import Base, SubscriptionStatus, User
from app.services import auth_service

TEST_EMAIL = "surucu@stopkoc.com"
TEST_PASSWORD = "Sifre123"


@pytest.fixture
async def session_factory() -> AsyncIterator[async_sessionmaker[AsyncSession]]:
    """Her test için sıfırdan bir bellek içi veritabanı kurar.

    `StaticPool` tek bağlantıyı paylaştırır; aksi hâlde SQLite bellek
    veritabanı her yeni bağlantıda boş başlar.
    """
    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        poolclass=StaticPool,
        connect_args={"check_same_thread": False},
    )

    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)

    factory = async_sessionmaker(engine, expire_on_commit=False, autoflush=False)
    try:
        yield factory
    finally:
        await engine.dispose()


@pytest.fixture
async def session(
    session_factory: async_sessionmaker[AsyncSession],
) -> AsyncIterator[AsyncSession]:
    """Testin doğrudan veritabanına bakması için bir oturum."""
    async with session_factory() as session:
        yield session


@pytest.fixture
async def client(
    session_factory: async_sessionmaker[AsyncSession],
) -> AsyncIterator[AsyncClient]:
    """Uygulamayı ağ üzerinden değil ASGI katmanından çağıran istemci."""

    async def override_get_session() -> AsyncIterator[AsyncSession]:
        async with session_factory() as session:
            try:
                yield session
            except Exception:
                await session.rollback()
                raise

    app.dependency_overrides[get_session] = override_get_session

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as http:
        yield http

    app.dependency_overrides.clear()


@pytest.fixture
async def registered_user(
    session_factory: async_sessionmaker[AsyncSession],
) -> User:
    """Arayüzden geçmeden bir kullanıcı oluşturur."""
    async with session_factory() as session:
        return await auth_service.register_user(
            session,
            email=TEST_EMAIL,
            password=TEST_PASSWORD,
        )


@pytest.fixture
async def auth_headers(client: AsyncClient) -> dict[str, str]:
    """Kayıt olup `Authorization` başlığı üretir."""
    response = await client.post(
        "/api/v1/auth/register",
        json={"email": TEST_EMAIL, "password": TEST_PASSWORD},
    )
    assert response.status_code == 201, response.text
    token = response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
async def ai_pro_headers(
    client: AsyncClient,
    auth_headers: dict[str, str],
    session_factory: async_sessionmaker[AsyncSession],
) -> dict[str, str]:
    """AI Pro paketi etkin bir kullanıcının başlıkları."""
    response = await client.patch(
        "/api/v1/auth/me/subscription",
        json={"subscription_status": SubscriptionStatus.ai_pro.value},
        headers=auth_headers,
    )
    assert response.status_code == 200, response.text
    return auth_headers
