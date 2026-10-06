"""Veritabanı motoru ve oturum yönetimi (async SQLAlchemy 2.0)."""

from __future__ import annotations

from collections.abc import AsyncIterator

from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.core.config import settings


def create_engine(url: str | None = None) -> AsyncEngine:
    """Verilen bağlantı adresi için bir motor oluşturur.

    SQLite (testler) havuz ayarlarını desteklemediği için yalnızca
    PostgreSQL'de havuz parametreleri geçilir.
    """
    target = url or settings.database_url
    kwargs: dict[str, object] = {
        "echo": settings.db_echo,
        "future": True,
    }

    if target.startswith("sqlite"):
        kwargs["connect_args"] = {"check_same_thread": False}
    else:
        kwargs |= {
            "pool_pre_ping": True,  # kopmuş bağlantıları isteğe girmeden yakalar
            "pool_size": settings.db_pool_size,
            "max_overflow": settings.db_max_overflow,
        }

    return create_async_engine(target, **kwargs)


engine: AsyncEngine = create_engine()

SessionFactory = async_sessionmaker(
    bind=engine,
    expire_on_commit=False,  # commit sonrası nesneler okunabilir kalsın
    autoflush=False,
)


async def get_session() -> AsyncIterator[AsyncSession]:
    """İstek başına bir veritabanı oturumu verir.

    Commit'i servis katmanı yapar; burada yalnızca hata hâlinde geri alma
    ve kapatma garanti edilir.
    """
    async with SessionFactory() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise


async def dispose_engine() -> None:
    """Uygulama kapanırken havuzu boşaltır."""
    await engine.dispose()
