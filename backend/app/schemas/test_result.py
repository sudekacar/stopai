"""Test sonucu istek/yanıt şemaları."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, computed_field

from app.models.test_result import PASSING_SCORE


class TestResultCreate(BaseModel):
    """Mobil uygulamanın test bitiminde gönderdiği kayıt."""

    test_id: int = Field(ge=1, description="Deneme testi numarası (1-20).")
    score: int = Field(ge=0, le=100, description="Yüzde cinsinden başarı.")

    # Çevrimdışı çözülen testlerin sonradan gönderilebilmesi için istemci
    # kendi zamanını bildirebilir; boş bırakılırsa sunucu saati kullanılır.
    completed_at: datetime | None = None


class TestResultRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    test_id: int
    score: int
    completed_at: datetime

    @computed_field
    @property
    def passed(self) -> bool:
        return self.score >= PASSING_SCORE


class TestResultPage(BaseModel):
    """Sayfalanmış sonuç listesi."""

    items: list[TestResultRead]
    total: int
    limit: int
    offset: int


class TestBreakdown(BaseModel):
    """Tek bir deneme testi için özet."""

    test_id: int
    attempts: int
    best_score: int
    last_score: int
    last_completed_at: datetime


class StatsResponse(BaseModel):
    """Profil ekranının beslendiği toplu istatistikler."""

    total_attempts: int = Field(description="Toplam çözülen test denemesi.")
    completed_test_count: int = Field(
        description="Kaç farklı testin tamamlandığı (tekrarlar bir kez sayılır)."
    )
    average_score: int = Field(description="Tüm denemelerin ortalaması (0-100).")
    best_score: int
    passed_attempts: int = Field(
        description=f"Başarı yüzdesi {PASSING_SCORE} ve üzeri olan deneme sayısı."
    )
    last_completed_at: datetime | None
    per_test: list[TestBreakdown]
