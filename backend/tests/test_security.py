"""Şifre hashleme ve JWT birim testleri."""

from __future__ import annotations

from datetime import timedelta

import jwt
import pytest

from app.core.config import settings
from app.core.exceptions import InvalidToken, TokenExpired
from app.core.security import (
    create_access_token,
    decode_access_token,
    hash_password,
    verify_password,
)


class TestPasswordHashing:
    def test_hash_is_not_reversible(self) -> None:
        digest = hash_password("Sifre123")

        assert "Sifre123" not in digest
        assert digest.startswith("$2b$")

    def test_same_password_produces_different_hashes(self) -> None:
        first = hash_password("Sifre123")
        second = hash_password("Sifre123")

        # Salt sayesinde iki özet farklı ama ikisi de doğrulanır.
        assert first != second
        assert verify_password("Sifre123", first)
        assert verify_password("Sifre123", second)

    def test_wrong_password_fails(self) -> None:
        digest = hash_password("Sifre123")

        assert not verify_password("sifre123", digest)
        assert not verify_password("Sifre1234", digest)
        assert not verify_password("", digest)

    def test_long_password_is_supported(self) -> None:
        """bcrypt 72 baytta kesiyor; SHA-256 ön özeti bunu aşmalı."""
        base = "A1" * 60  # 120 karakter
        digest = hash_password(base)

        assert verify_password(base, digest)
        # İlk 72 baytı aynı olan farklı bir şifre kabul edilmemeli.
        assert not verify_password(base + "farkli9", digest)

    def test_broken_hash_record_returns_false(self) -> None:
        assert not verify_password("Sifre123", "bozuk-kayit")


class TestAccessToken:
    def test_round_trip(self) -> None:
        token = create_access_token(42)
        payload = decode_access_token(token.token)

        assert payload.user_id == 42
        assert token.expires_in == settings.access_token_expire_minutes * 60
        assert payload.token_id

    def test_expired_token_is_rejected(self) -> None:
        token = create_access_token(1, expires_delta=timedelta(seconds=-10))

        with pytest.raises(TokenExpired):
            decode_access_token(token.token)

    def test_tampered_signature_is_rejected(self) -> None:
        token = create_access_token(1)
        forged = jwt.encode(
            {"sub": "1", "exp": 9999999999, "type": "access"},
            # Saldırganın anahtarı: RFC 7518'in önerdiği uzunlukta olsa da
            # imza bizim anahtarımızla doğrulanamaz.
            "saldirgan-anahtari-32-bayttan-uzun-olsun",
            algorithm=settings.jwt_algorithm,
        )

        assert forged != token.token
        with pytest.raises(InvalidToken):
            decode_access_token(forged)

    def test_wrong_token_type_is_rejected(self) -> None:
        other = jwt.encode(
            {"sub": "1", "exp": 9999999999, "type": "refresh"},
            settings.jwt_secret_key,
            algorithm=settings.jwt_algorithm,
        )

        with pytest.raises(InvalidToken):
            decode_access_token(other)

    def test_garbage_token_is_rejected(self) -> None:
        with pytest.raises(InvalidToken):
            decode_access_token("bu-bir-jwt-degil")
