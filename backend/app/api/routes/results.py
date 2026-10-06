"""Test sonuçları ve istatistik uçları."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Query, status

from app.api.deps import CurrentUser, SessionDep
from app.models.test_result import TestResult
from app.schemas.test_result import (
    StatsResponse,
    TestResultCreate,
    TestResultPage,
    TestResultRead,
)
from app.services import result_service

router = APIRouter(prefix="/results", tags=["results"])


@router.post(
    "",
    response_model=TestResultRead,
    status_code=status.HTTP_201_CREATED,
    summary="Çözülen testin skorunu kaydet",
)
async def create_result(
    payload: TestResultCreate,
    user: CurrentUser,
    session: SessionDep,
) -> TestResult:
    """Test bitiminde mobil uygulamanın gönderdiği sonucu saklar.

    `user_id` istekten okunmaz, JWT'den gelir: bir kullanıcı başkasının
    adına sonuç yazamaz.
    """
    return await result_service.create_result(
        session,
        user_id=user.id,
        test_id=payload.test_id,
        score=payload.score,
        completed_at=payload.completed_at,
    )


@router.get(
    "",
    response_model=TestResultPage,
    summary="Geçmiş test sonuçlarını listele",
)
async def list_results(
    user: CurrentUser,
    session: SessionDep,
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
    test_id: Annotated[int | None, Query(ge=1)] = None,
) -> TestResultPage:
    """Sonuçları en yeniden eskiye döner; istenirse tek teste filtrelenir."""
    items, total = await result_service.list_results(
        session,
        user_id=user.id,
        limit=limit,
        offset=offset,
        test_id=test_id,
    )

    return TestResultPage(
        items=[TestResultRead.model_validate(item) for item in items],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.get(
    "/stats",
    response_model=StatsResponse,
    summary="Başarı istatistiklerini getir",
)
async def read_stats(user: CurrentUser, session: SessionDep) -> StatsResponse:
    """Profil ekranının gösterdiği toplu istatistikler.

    Hiç test çözülmemişse tüm sayaçlar sıfır döner, hata verilmez.
    """
    return await result_service.get_stats(session, user_id=user.id)
