"""Test sonucu kaydı, listeleme ve istatistik uçlarının testleri."""

from __future__ import annotations

from datetime import UTC, datetime

from httpx import AsyncClient

RESULTS_URL = "/api/v1/results"
STATS_URL = "/api/v1/results/stats"


async def _post_result(
    client: AsyncClient,
    headers: dict[str, str],
    *,
    test_id: int,
    score: int,
    completed_at: datetime | None = None,
) -> dict:
    payload: dict[str, object] = {"test_id": test_id, "score": score}
    if completed_at is not None:
        payload["completed_at"] = completed_at.isoformat()

    response = await client.post(RESULTS_URL, json=payload, headers=headers)
    assert response.status_code == 201, response.text
    return response.json()


class TestCreateResult:
    async def test_result_is_saved(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
    ) -> None:
        body = await _post_result(client, auth_headers, test_id=1, score=90)

        assert body["test_id"] == 1
        assert body["score"] == 90
        assert body["passed"] is True
        assert body["completed_at"]

    async def test_score_below_passing_is_marked_failed(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
    ) -> None:
        body = await _post_result(client, auth_headers, test_id=2, score=60)

        assert body["passed"] is False

    async def test_client_supplied_completion_time_is_kept(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
    ) -> None:
        moment = datetime(2026, 9, 20, 10, 30, tzinfo=UTC)

        body = await _post_result(
            client,
            auth_headers,
            test_id=3,
            score=80,
            completed_at=moment,
        )

        assert body["completed_at"].startswith("2026-09-20T10:30")

    async def test_requires_authentication(self, client: AsyncClient) -> None:
        response = await client.post(
            RESULTS_URL,
            json={"test_id": 1, "score": 90},
        )

        assert response.status_code == 401

    async def test_invalid_payloads_are_rejected(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
    ) -> None:
        invalid = [
            {"test_id": 0, "score": 50},  # test numarası 1'den küçük
            {"test_id": 1, "score": -1},  # negatif skor
            {"test_id": 1, "score": 101},  # 100'den büyük skor
            {"test_id": 1},  # skor yok
        ]

        for payload in invalid:
            response = await client.post(
                RESULTS_URL, json=payload, headers=auth_headers
            )
            assert response.status_code == 422, payload


class TestListResults:
    async def test_results_are_newest_first(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
    ) -> None:
        await _post_result(
            client,
            auth_headers,
            test_id=1,
            score=50,
            completed_at=datetime(2026, 9, 20, tzinfo=UTC),
        )
        await _post_result(
            client,
            auth_headers,
            test_id=2,
            score=95,
            completed_at=datetime(2026, 9, 24, tzinfo=UTC),
        )

        response = await client.get(RESULTS_URL, headers=auth_headers)

        assert response.status_code == 200
        body = response.json()
        assert body["total"] == 2
        assert [item["test_id"] for item in body["items"]] == [2, 1]

    async def test_pagination(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
    ) -> None:
        for index in range(5):
            await _post_result(
                client,
                auth_headers,
                test_id=index + 1,
                score=70,
                completed_at=datetime(2026, 9, index + 1, tzinfo=UTC),
            )

        response = await client.get(
            RESULTS_URL,
            params={"limit": 2, "offset": 1},
            headers=auth_headers,
        )

        body = response.json()
        assert body["total"] == 5
        assert body["limit"] == 2
        assert body["offset"] == 1
        assert len(body["items"]) == 2

    async def test_filter_by_test_id(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
    ) -> None:
        await _post_result(client, auth_headers, test_id=1, score=60)
        await _post_result(client, auth_headers, test_id=1, score=90)
        await _post_result(client, auth_headers, test_id=2, score=80)

        response = await client.get(
            RESULTS_URL,
            params={"test_id": 1},
            headers=auth_headers,
        )

        body = response.json()
        assert body["total"] == 2
        assert {item["test_id"] for item in body["items"]} == {1}

    async def test_users_cannot_see_each_others_results(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
    ) -> None:
        await _post_result(client, auth_headers, test_id=1, score=90)

        other = await client.post(
            "/api/v1/auth/register",
            json={"email": "baska@stopkoc.com", "password": "Sifre123"},
        )
        other_headers = {"Authorization": f"Bearer {other.json()['access_token']}"}

        response = await client.get(RESULTS_URL, headers=other_headers)

        assert response.json()["total"] == 0


class TestStats:
    async def test_empty_stats(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
    ) -> None:
        response = await client.get(STATS_URL, headers=auth_headers)

        assert response.status_code == 200
        body = response.json()
        assert body["total_attempts"] == 0
        assert body["completed_test_count"] == 0
        assert body["average_score"] == 0
        assert body["best_score"] == 0
        assert body["last_completed_at"] is None
        assert body["per_test"] == []

    async def test_aggregates(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
    ) -> None:
        # 1. test iki kez çözüldü (50 ve 90), 2. test bir kez (80).
        await _post_result(
            client,
            auth_headers,
            test_id=1,
            score=50,
            completed_at=datetime(2026, 9, 20, tzinfo=UTC),
        )
        await _post_result(
            client,
            auth_headers,
            test_id=1,
            score=90,
            completed_at=datetime(2026, 9, 22, tzinfo=UTC),
        )
        await _post_result(
            client,
            auth_headers,
            test_id=2,
            score=80,
            completed_at=datetime(2026, 9, 24, tzinfo=UTC),
        )

        body = (await client.get(STATS_URL, headers=auth_headers)).json()

        assert body["total_attempts"] == 3
        # Aynı test tekrar çözülse de bir kez sayılır.
        assert body["completed_test_count"] == 2
        assert body["average_score"] == 73  # (50+90+80)/3 = 73.33 -> 73
        assert body["best_score"] == 90
        assert body["passed_attempts"] == 2  # 90 ve 80
        assert body["last_completed_at"].startswith("2026-09-24")

    async def test_per_test_breakdown(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
    ) -> None:
        await _post_result(
            client,
            auth_headers,
            test_id=4,
            score=95,
            completed_at=datetime(2026, 9, 20, tzinfo=UTC),
        )
        await _post_result(
            client,
            auth_headers,
            test_id=4,
            score=60,
            completed_at=datetime(2026, 9, 25, tzinfo=UTC),
        )

        body = (await client.get(STATS_URL, headers=auth_headers)).json()
        breakdown = body["per_test"][0]

        assert breakdown["test_id"] == 4
        assert breakdown["attempts"] == 2
        assert breakdown["best_score"] == 95
        # En son deneme daha kötü olsa da ayrı raporlanır.
        assert breakdown["last_score"] == 60
        assert breakdown["last_completed_at"].startswith("2026-09-25")

    async def test_requires_authentication(self, client: AsyncClient) -> None:
        response = await client.get(STATS_URL)

        assert response.status_code == 401
