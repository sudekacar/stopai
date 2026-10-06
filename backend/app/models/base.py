"""ORM taban sınıfı ve ortak yardımcılar."""

from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    """Tüm tabloların türediği taban sınıf.

    Alembic `target_metadata` olarak `Base.metadata` kullanır.
    """


def utcnow() -> datetime:
    """Zaman dilimi bilgisi taşıyan şimdiki zaman.

    `datetime.utcnow()` naive değer döndürdüğü için doğrudan kullanılmıyor.
    """
    return datetime.now(UTC)
