"""Kayıt, giriş ve JWT korumalı uçların testleri."""

from __future__ import annotations

from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models import SubscriptionStatus, User

from .conftest import TEST_EMAIL, TEST_PASSWORD

REGISTER_URL = "/api/v1/auth/register"
LOGIN_URL = "/api/v1/auth/login"
ME_URL = "/api/v1/auth/me"


class TestRegister:
    async def test_register_returns_token_and_user(
        self, client: AsyncClient
    ) -> None:
        response = await client.post(
            REGISTER_URL,
            json={"email": TEST_EMAIL, "password": TEST_PASSWORD},
        )

        assert response.status_code == 201
        body = response.json()
        assert body["token_type"] == "bearer"
        assert body["access_token"]
        assert body["expires_in"] > 0
        assert body["user"]["email"] == TEST_EMAIL
        assert body["user"]["subscription_status"] == "free"
        # Özet hiçbir koşulda yanıtta yer almamalı.
        assert "password_hash" not in body["user"]

    async def test_email_is_normalized(self, client: AsyncClient) -> None:
        response = await client.post(
            REGISTER_URL,
            json={"email": "  Surucu@StopKoc.COM ", "password": TEST_PASSWORD},
        )

        assert response.status_code == 201
        assert response.json()["user"]["email"] == TEST_EMAIL

    async def test_password_is_stored_hashed(
        self,
        client: AsyncClient,
        session: AsyncSession,
    ) -> None:
        await client.post(
            REGISTER_URL,
            json={"email": TEST_EMAIL, "password": TEST_PASSWORD},
        )

        user = (
            await session.execute(select(User).where(User.email == TEST_EMAIL))
        ).scalar_one()

        assert user.password_hash != TEST_PASSWORD
        assert user.password_hash.startswith("$2b$")

    async def test_duplicate_email_is_rejected(self, client: AsyncClient) -> None:
        payload = {"email": TEST_EMAIL, "password": TEST_PASSWORD}
        await client.post(REGISTER_URL, json=payload)

        response = await client.post(REGISTER_URL, json=payload)

        assert response.status_code == 409
        assert response.json()["error_code"] == "email_already_registered"

    async def test_duplicate_email_is_case_insensitive(
        self, client: AsyncClient
    ) -> None:
        await client.post(
            REGISTER_URL,
            json={"email": TEST_EMAIL, "password": TEST_PASSWORD},
        )

        response = await client.post(
            REGISTER_URL,
            json={"email": TEST_EMAIL.upper(), "password": TEST_PASSWORD},
        )

        assert response.status_code == 409

    async def test_invalid_email_is_rejected(self, client: AsyncClient) -> None:
        response = await client.post(
            REGISTER_URL,
            json={"email": "gecersiz-eposta", "password": TEST_PASSWORD},
        )

        assert response.status_code == 422

    async def test_weak_passwords_are_rejected(self, client: AsyncClient) -> None:
        for weak in ("abc12", "sadeceharf", "123456"):
            response = await client.post(
                REGISTER_URL,
                json={"email": f"{weak}@stopkoc.com", "password": weak},
            )
            assert response.status_code == 422, weak


class TestLogin:
    async def test_login_with_correct_password(self, client: AsyncClient) -> None:
        await client.post(
            REGISTER_URL,
            json={"email": TEST_EMAIL, "password": TEST_PASSWORD},
        )

        response = await client.post(
            LOGIN_URL,
            json={"email": TEST_EMAIL, "password": TEST_PASSWORD},
        )

        assert response.status_code == 200
        assert response.json()["access_token"]

    async def test_wrong_password_is_rejected(self, client: AsyncClient) -> None:
        await client.post(
            REGISTER_URL,
            json={"email": TEST_EMAIL, "password": TEST_PASSWORD},
        )

        response = await client.post(
            LOGIN_URL,
            json={"email": TEST_EMAIL, "password": "Yanlis999"},
        )

        assert response.status_code == 401
        assert response.json()["error_code"] == "invalid_credentials"

    async def test_unknown_email_gives_same_message(
        self, client: AsyncClient
    ) -> None:
        """Hesabın var olup olmadığı yanıttan anlaşılmamalı."""
        response = await client.post(
            LOGIN_URL,
            json={"email": "yok@stopkoc.com", "password": TEST_PASSWORD},
        )

        assert response.status_code == 401
        assert response.json()["detail"] == "E-posta veya şifre hatalı."


class TestProtectedEndpoints:
    async def test_me_requires_token(self, client: AsyncClient) -> None:
        response = await client.get(ME_URL)

        assert response.status_code == 401
        assert response.json()["error_code"] == "not_authenticated"
        assert response.headers["WWW-Authenticate"] == "Bearer"

    async def test_me_returns_current_user(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
    ) -> None:
        response = await client.get(ME_URL, headers=auth_headers)

        assert response.status_code == 200
        assert response.json()["email"] == TEST_EMAIL

    async def test_invalid_token_is_rejected(self, client: AsyncClient) -> None:
        response = await client.get(
            ME_URL,
            headers={"Authorization": "Bearer bu-bir-jwt-degil"},
        )

        assert response.status_code == 401
        assert response.json()["error_code"] == "invalid_token"

    async def test_token_of_deleted_user_is_rejected(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        session_factory: async_sessionmaker[AsyncSession],
    ) -> None:
        async with session_factory() as session:
            user = (
                await session.execute(select(User).where(User.email == TEST_EMAIL))
            ).scalar_one()
            await session.delete(user)
            await session.commit()

        response = await client.get(ME_URL, headers=auth_headers)

        assert response.status_code == 401
        assert response.json()["error_code"] == "invalid_token"


class TestSubscription:
    async def test_subscription_can_be_updated(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
    ) -> None:
        response = await client.patch(
            "/api/v1/auth/me/subscription",
            json={"subscription_status": SubscriptionStatus.ai_pro.value},
            headers=auth_headers,
        )

        assert response.status_code == 200
        assert response.json()["subscription_status"] == "ai_pro"

    async def test_unknown_subscription_value_is_rejected(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
    ) -> None:
        response = await client.patch(
            "/api/v1/auth/me/subscription",
            json={"subscription_status": "bedava_her_sey"},
            headers=auth_headers,
        )

        assert response.status_code == 422
