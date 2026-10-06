"""Test sonuçları tablosu."""

from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, utcnow

if TYPE_CHECKING:
    from app.models.user import User

# Geçme notu; mobil uygulamadaki `TestAttempt.passingPercentage` ile aynı.
PASSING_SCORE = 70


class TestResult(Base):
    __tablename__ = "test_results"

    __table_args__ = (
        CheckConstraint("score >= 0 AND score <= 100", name="ck_test_results_score"),
        CheckConstraint("test_id >= 1", name="ck_test_results_test_id"),
        # İstatistik sorguları hep "bir kullanıcının belirli testi" üzerinden
        # gittiği için bileşik indeks kullanıyoruz.
        Index("ix_test_results_user_test", "user_id", "test_id"),
        Index("ix_test_results_user_completed", "user_id", "completed_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # Mobil uygulamadaki deneme testi numarası (1-20).
    test_id: Mapped[int] = mapped_column(Integer, nullable=False)

    # Yüzde cinsinden başarı (0-100).
    score: Mapped[int] = mapped_column(Integer, nullable=False)

    completed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        server_default=func.now(),
        nullable=False,
        index=True,
    )

    user: Mapped[User] = relationship(back_populates="test_results", lazy="raise")

    @property
    def passed(self) -> bool:
        return self.score >= PASSING_SCORE

    def __repr__(self) -> str:
        return (
            f"<TestResult id={self.id} user_id={self.user_id} "
            f"test_id={self.test_id} score={self.score}>"
        )
