"""지도 진행 API 테스트 (GET /api/v1/users/me/map)."""

from datetime import UTC, datetime
from uuid import UUID

from httpx import AsyncClient

from tests.helpers import (
    DODAM_LAT,
    DODAM_LNG,
    auth_headers,
    complete_auth_headers,
    login,
    seed_quest_fixture,
)


async def _seed_map_fixture(user_id: UUID) -> dict[str, str]:
    """표준 지역 중 단양군에만 map_progress 레코드를 생성한다."""
    from sqlalchemy import select

    from app.core.database import AsyncSessionLocal
    from app.progress.models import MapProgress
    from app.regions.models import Region

    async with AsyncSessionLocal() as session:
        danyang = (
            await session.execute(select(Region).where(Region.slug == "danyang"))
        ).scalar_one()
        cheongju = (
            await session.execute(select(Region).where(Region.slug == "cheongju"))
        ).scalar_one()

        progress = MapProgress(
            user_id=user_id,
            region_id=danyang.id,
            completed_count=3,
            first_colored_at=datetime(2026, 7, 1, 10, 0, 0, tzinfo=UTC),
        )
        session.add(progress)
        await session.commit()

        return {
            "danyang_id": str(danyang.id),
            "cheongju_id": str(cheongju.id),
        }


async def test_my_map_returns_all_regions(client: AsyncClient) -> None:
    """방문한 지역·미방문 지역 모두 반환하고 completed_count가 정확해야 한다."""
    data = await login(client)
    user_id = UUID(data["user"]["id"])
    headers = await complete_auth_headers(client, data)
    seed = await _seed_map_fixture(user_id)

    response = await client.get("/api/v1/users/me/map", headers=headers)
    assert response.status_code == 200
    items = response.json()["data"]

    assert len(items) == 11

    by_region = {item["region_id"]: item for item in items}
    assert by_region[seed["danyang_id"]]["region_name"] == "단양군"
    assert by_region[seed["danyang_id"]]["completed_count"] == 3
    assert by_region[seed["danyang_id"]]["first_colored_at"] is not None
    assert by_region[seed["cheongju_id"]]["region_name"] == "청주시"
    assert by_region[seed["cheongju_id"]]["completed_count"] == 0
    assert by_region[seed["cheongju_id"]]["first_colored_at"] is None

    # 완료한 여정이 없으므로 채색 기준값은 모두 0이다 (055-journey-map-coloring).
    assert all(item["completed_journey_count"] == 0 for item in items)


async def test_my_map_only_returns_my_progress(client: AsyncClient) -> None:
    """다른 유저의 map_progress는 내 응답에 포함되지 않는다."""
    owner_data = await login(client, "kakao-token-1")
    other_data = await login(client, "kakao-token-unknown")

    owner_id = UUID(owner_data["user"]["id"])
    owner_headers = await complete_auth_headers(client, owner_data)
    other_headers = await complete_auth_headers(client, other_data)

    seed = await _seed_map_fixture(owner_id)

    owner_items = {
        item["region_id"]: item
        for item in (await client.get("/api/v1/users/me/map", headers=owner_headers)).json()["data"]
    }
    assert owner_items[seed["danyang_id"]]["completed_count"] == 3

    other_items = {
        item["region_id"]: item
        for item in (await client.get("/api/v1/users/me/map", headers=other_headers)).json()["data"]
    }
    assert other_items[seed["danyang_id"]]["completed_count"] == 0


async def _get_map_by_region(client: AsyncClient, headers: dict[str, str]) -> dict[str, dict]:
    """지도 응답을 region_id 키의 dict로 변환해 반환한다."""
    response = await client.get("/api/v1/users/me/map", headers=headers)
    assert response.status_code == 200
    return {item["region_id"]: item for item in response.json()["data"]}


async def test_my_map_counts_completed_journeys(client: AsyncClient) -> None:
    """여정을 완주하면 해당 지역의 completed_journey_count가 증가한다 (035)."""
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    # 여정 생성 직후(진행 중)에는 완료 여정 수에 반영되지 않는다.
    created = await client.post(
        "/api/v1/journeys",
        json={"region_id": seed["region_id"], "quest_ids": [seed["gps_quest_id"]]},
        headers=headers,
    )
    assert created.status_code == 201

    before = await _get_map_by_region(client, headers)
    assert before[seed["region_id"]]["completed_journey_count"] == 0

    # 퀘스트 인증 → 여정이 completed로 전이 (test_journey_flow.py 패턴).
    verify = await client.post(
        f"/api/v1/quests/{seed['gps_quest_id']}/verify",
        json={"lat": str(DODAM_LAT), "lng": str(DODAM_LNG), "photo_url": "/uploads/photos/x.jpg"},
        headers=headers,
    )
    assert verify.json()["data"]["verified"] is True

    after = await _get_map_by_region(client, headers)
    assert after[seed["region_id"]]["completed_journey_count"] == 1
    assert after[seed["other_region_id"]]["completed_journey_count"] == 0

    # 완료 기록은 여정별로 소유된다. 같은 퀘스트로 새 여정을 만들어도 기존 여정의
    # 완료 기록이 다른 여정에 중복 집계되지는 않는다.
    second = await client.post(
        "/api/v1/journeys",
        json={"region_id": seed["region_id"], "quest_ids": [seed["gps_quest_id"]]},
        headers=headers,
    )
    assert second.status_code == 201
    assert second.json()["data"]["status"] == "in_progress"

    again = await _get_map_by_region(client, headers)
    assert again[seed["region_id"]]["completed_journey_count"] == 1


async def test_my_map_preserves_legacy_null_journey_progress_count(
    client: AsyncClient,
) -> None:
    """배포 전 journey_id가 비어 있던 완료 기록도 채색 집계에서 사라지면 안 된다."""
    from sqlalchemy import update

    from app.core.database import AsyncSessionLocal
    from app.quests.models import QuestProgress

    seed = await seed_quest_fixture()
    headers = await auth_headers(client)
    created = await client.post(
        "/api/v1/journeys",
        json={"region_id": seed["region_id"], "quest_ids": [seed["gps_quest_id"]]},
        headers=headers,
    )
    assert created.status_code == 201

    verify = await client.post(
        f"/api/v1/quests/{seed['gps_quest_id']}/verify",
        json={"lat": str(DODAM_LAT), "lng": str(DODAM_LNG), "photo_url": "/uploads/photos/x.jpg"},
        headers=headers,
    )
    assert verify.json()["data"]["verified"] is True

    async with AsyncSessionLocal() as session:
        await session.execute(
            update(QuestProgress)
            .where(QuestProgress.id == UUID(verify.json()["data"]["progress"]["id"]))
            .values(journey_id=None)
        )
        await session.commit()

    legacy = await _get_map_by_region(client, headers)
    assert legacy[seed["region_id"]]["completed_journey_count"] == 1

    second = await client.post(
        "/api/v1/journeys",
        json={"region_id": seed["region_id"], "quest_ids": [seed["gps_quest_id"]]},
        headers=headers,
    )
    assert second.status_code == 201

    after_second = await _get_map_by_region(client, headers)
    assert after_second[seed["region_id"]]["completed_journey_count"] == 1


async def test_my_map_counts_journey_with_single_completed_quest(client: AsyncClient) -> None:
    """퀘스트를 여러 개 담고 1개만 인증해도 그 여행이 채색 집계에 1회로 들어간다 (KAN-73).

    여정이 진행중(in_progress)이어도 집계에 포함된다 — 채색은 status와 무관하다
    (docs/specs/055-journey-map-coloring/description.md).
    """
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    created = await client.post(
        "/api/v1/journeys",
        json={
            "region_id": seed["region_id"],
            "quest_ids": [
                seed["quiz_quest_id"],
                seed["gps_only_quest_id"],
                seed["food_quest_id"],
            ],
        },
        headers=headers,
    )
    assert created.status_code == 201

    before = await _get_map_by_region(client, headers)
    assert before[seed["region_id"]]["completed_journey_count"] == 0

    # 3개 중 퀴즈 1개만 인증한다.
    verify = await client.post(
        f"/api/v1/quests/{seed['quiz_quest_id']}/verify",
        json={"answer": "O"},
        headers=headers,
    )
    assert verify.json()["data"]["verified"] is True

    detail = await client.get(f"/api/v1/journeys/{created.json()['data']['id']}", headers=headers)
    assert detail.json()["data"]["status"] == "in_progress"  # 기간이 남아 있고 부분 완료
    assert detail.json()["data"]["progress"] == {"completed": 1, "total": 3}

    after = await _get_map_by_region(client, headers)
    assert after[seed["region_id"]]["completed_journey_count"] == 1
    assert after[seed["other_region_id"]]["completed_journey_count"] == 0


async def test_my_map_counts_one_per_journey_even_with_many_completed_quests(
    client: AsyncClient,
) -> None:
    """한 여행에서 퀘스트를 2개 인증해도 채색 집계는 여행 단위로 1회다 (KAN-73)."""
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    await client.post(
        "/api/v1/journeys",
        json={
            "region_id": seed["region_id"],
            "quest_ids": [seed["quiz_quest_id"], seed["gps_quest_id"]],
        },
        headers=headers,
    )
    await client.post(
        f"/api/v1/quests/{seed['quiz_quest_id']}/verify",
        json={"answer": "O"},
        headers=headers,
    )
    await client.post(
        f"/api/v1/quests/{seed['gps_quest_id']}/verify",
        json={"lat": str(DODAM_LAT), "lng": str(DODAM_LNG), "photo_url": "/uploads/photos/x.jpg"},
        headers=headers,
    )

    result = await _get_map_by_region(client, headers)
    assert result[seed["region_id"]]["completed_journey_count"] == 1


async def test_my_map_journey_count_is_private_to_owner(client: AsyncClient) -> None:
    """다른 유저의 완료 여정은 내 completed_journey_count에 포함되지 않는다."""
    seed = await seed_quest_fixture()
    owner_headers = await auth_headers(client)
    other_headers = await auth_headers(client, token="kakao-token-unknown")

    await client.post(
        "/api/v1/journeys",
        json={"region_id": seed["region_id"], "quest_ids": [seed["gps_quest_id"]]},
        headers=owner_headers,
    )
    await client.post(
        f"/api/v1/quests/{seed['gps_quest_id']}/verify",
        json={"lat": str(DODAM_LAT), "lng": str(DODAM_LNG), "photo_url": "/uploads/photos/x.jpg"},
        headers=owner_headers,
    )

    owner_map = await _get_map_by_region(client, owner_headers)
    assert owner_map[seed["region_id"]]["completed_journey_count"] == 1

    other_map = await _get_map_by_region(client, other_headers)
    assert other_map[seed["region_id"]]["completed_journey_count"] == 0


async def test_my_map_requires_auth(client: AsyncClient) -> None:
    """인증 없이 호출하면 401을 반환해야 한다."""
    response = await client.get("/api/v1/users/me/map")
    assert response.status_code == 401
