"""Kullanıcı tablosu."""

from __future__ import annotations

import enum
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, Enum, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, utcnow

if TYPE_CHECKING:
    from app.models.test_result import TestResult


class SubscriptionStatus(str, enum.Enum):
    """Mobil uygulamadaki paket durumlarının sunucu karşılığı.

    - `free`: yalnızca 1. deneme testi açık, reklamlar görünür.
    - `lifetime_tests`: 99 TL paketi, 2-20 arası testler açık.
    - `ai_pro`: 299 TL paketi, AI çalışma alanı da açık.
    """

    free = "free"
    lifetime_tests = "lifetime_tests"
    ai_pro = "ai_pro"

    @property
    def unlocks_all_tests(self) -> bool:
        return self in (SubscriptionStatus.lifetime_tests, SubscriptionStatus.ai_pro)

    @property
    def unlocks_ai(self) -> bool:
        return self is SubscriptionStatus.ai_pro


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)

    email: Mapped[str] = mapped_column(
        String(320),  # RFC 5321 üst sınırı
        unique=True,
        index=True,
        nullable=False,
    )

    # Şifrenin kendisi asla saklanmaz; bkz. app/core/security.py
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        server_default=func.now(),
        nullable=False,
    )

    subscription_status: Mapped[SubscriptionStatus] = mapped_column(
        Enum(
            SubscriptionStatus,
            name="subscription_status",
            # Veritabanına enum adları yerine değerleri yaz: kayıtlar
            # mobil uygulamadaki karşılıklarıyla birebir okunabilir olsun.
            values_callable=lambda enum_cls: [member.value for member in enum_cls],
        ),
        default=SubscriptionStatus.free,
        server_default=SubscriptionStatus.free.value,
        nullable=False,
    )

    test_results: Mapped[list[TestResult]] = relationship(
        back_populates="user",
        # Async oturumda kazara tembel yükleme yapılırsa sessizce bloke
        # olmak yerine açık hata versin.
        lazy="raise",
        # Silme işini veritabanındaki ON DELETE CASCADE üstlenir.
        passive_deletes=True,
    )

    def __repr__(self) -> str:
        return f"<User id={self.id} email={self.email!r}>"
