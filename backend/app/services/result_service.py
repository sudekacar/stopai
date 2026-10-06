"""Test sonuçlarının kaydı ve istatistik hesapları.

Toplamlar Python'da değil SQL'de hesaplanır: kullanıcının yüzlerce denemesi
olsa bile tek sorguyla dönmesi için.
"""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import Select, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.test_result import PASSING_SCORE, TestResult
from app.schemas.test_result import StatsResponse, TestBreakdown


async def create_result(
    session: AsyncSession,
    *,
    user_id: int,
    test_id: int,
    score: int,
    completed_at: datetime | None = None,
) -> TestResult:
    """Yeni bir test sonucu kaydeder."""
    result = TestResult(
        user_id=user_id,
        test_id=test_id,
        score=score,
    )
    if completed_at is not None:
        result.completed_at = completed_at

    session.add(result)
    await session.commit()
    await session.refresh(result)
    return result


def _user_results(user_id: int) -> Select[tuple[TestResult]]:
    return select(TestResult).where(TestResult.user_id == user_id)


async def list_results(
    session: AsyncSession,
    *,
    user_id: int,
    limit: int = 50,
    offset: int = 0,
    test_id: int | None = None,
) -> tuple[list[TestResult], int]:
    """Kullanıcının sonuçlarını en yeniden eskiye döner."""
    query = _user_results(user_id)
    count_query = select(func.count()).select_from(TestResult).where(
        TestResult.user_id == user_id
    )

    if test_id is not None:
        query = query.where(TestResult.test_id == test_id)
        count_query = count_query.where(TestResult.test_id == test_id)

    query = (
        query.order_by(TestResult.completed_at.desc(), TestResult.id.desc())
        .limit(limit)
        .offset(offset)
    )

    items = list((await session.execute(query)).scalars())
    total = int((await session.execute(count_query)).scalar_one())

    return items, total


async def get_stats(session: AsyncSession, *, user_id: int) -> StatsResponse:
    """Profil ekranının gösterdiği toplu istatistikleri hesaplar."""
    attempts, completed_tests, average_raw, best, last_completed_at = (
        await session.execute(
            select(
                func.count(TestResult.id),
                func.count(func.distinct(TestResult.test_id)),
                func.avg(TestResult.score),
                func.max(TestResult.score),
                func.max(TestResult.completed_at),
            ).where(TestResult.user_id == user_id)
        )
    ).one()

    average = round(float(average_raw)) if average_raw is not None else 0

    # Geçilen deneme sayısı ayrı sorguda: koşullu toplama (CASE/FILTER)
    # sözdizimi veritabanları arasında değişiyor, sayım her yerde aynı.
    passed = (
        await session.execute(
            select(func.count())
            .select_from(TestResult)
            .where(
                TestResult.user_id == user_id,
                TestResult.score >= PASSING_SCORE,
            )
        )
    ).scalar_one()

    return StatsResponse(
        total_attempts=int(attempts or 0),
        completed_test_count=int(completed_tests or 0),
        average_score=average,
        best_score=int(best or 0),
        passed_attempts=int(passed or 0),
        last_completed_at=last_completed_at,
        per_test=await _per_test_breakdown(session, user_id=user_id),
    )


async def _per_test_breakdown(
    session: AsyncSession,
    *,
    user_id: int,
) -> list[TestBreakdown]:
    """Her test için deneme sayısı, en iyi skor ve son deneme."""
    aggregates = (
        await session.execute(
            select(
                TestResult.test_id,
                func.count(TestResult.id),
                func.max(TestResult.score),
                func.max(TestResult.completed_at),
            )
            .where(TestResult.user_id == user_id)
            .group_by(TestResult.test_id)
            .order_by(TestResult.test_id)
        )
    ).all()

    if not aggregates:
        return []

    last_scores = await _last_score_per_test(session, user_id=user_id)

    return [
        TestBreakdown(
            test_id=test_id,
            attempts=int(attempts),
            best_score=int(best_score),
            last_score=last_scores.get(test_id, int(best_score)),
            last_completed_at=last_completed_at,
        )
        for test_id, attempts, best_score, last_completed_at in aggregates
    ]


async def _last_score_per_test(
    session: AsyncSession,
    *,
    user_id: int,
) -> dict[int, int]:
    """Her test için en son denemenin skoru.

    Pencere fonksiyonu yerine sıralı tek tarama: kullanıcı başına satır
    sayısı küçük olduğu için yeterli ve SQLite/PostgreSQL'de aynı çalışır.
    """
    rows = (
        await session.execute(
            select(TestResult.test_id, TestResult.score)
            .where(TestResult.user_id == user_id)
            .order_by(TestResult.completed_at.asc(), TestResult.id.asc())
        )
    ).all()

    # Sıralama eskiden yeniye olduğu için son yazan kazanır.
    return {int(test_id): int(score) for test_id, score in rows}
