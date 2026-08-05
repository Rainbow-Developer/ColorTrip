"""지자체 오픈 API 테스트 (docs/specs/070-municipal-open-api)."""

from __future__ import annotations

from datetime import datetime
from zoneinfo import ZoneInfo

import pytest
from httpx import AsyncClient

from app.core.database import AsyncSessionLocal
from app.core.security import generate_open_api_key, hash_open_api_key
from app.open_api.models import OpenApiKey
from tests.helpers import DODAM_LAT, DODAM_LNG, auth_headers, seed_quest_fixture

# 개인 식별 값(user_id·email 등)이 실수로 섞여 나오지 않는지 확인하기 위한 명시적 허용 목록.
_TOP_LEVEL_KEYS = {
    "region",
    "visit_stats",
    "popular_spots",
    "dna_distribution",
    "journey_completion",
    "verification_method_breakdown",
    "share_stats",
}
_REGION_KEYS = {"id", "name", "slug"}
_VISIT_STATS_KEYS = {"total_completed_quests", "monthly"}
_POPULAR_SPOT_KEYS = {"quest_id", "title", "completed_count"}
_JOURNEY_COMPLETION_KEYS = {"started", "completed", "completion_rate", "avg_days_to_complete"}
_SHARE_STATS_KEYS = {"total_shares", "by_style"}


async def _issue_key(name: str = "테스트 지자체") -> str:
    key = generate_open_api_key()
    async with AsyncSessionLocal() as session:
        session.add(OpenApiKey(name=name, key_hash=hash_open_api_key(key)))
        await session.commit()
    return key


@pytest.mark.asyncio
async def test_region_stats_reflects_completed_quest_and_share(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)
    service_key = await _issue_key()

    created = await client.post(
        "/api/v1/journeys",
        json={"region_id": seed["region_id"], "quest_ids": [seed["gps_quest_id"]]},
        headers=headers,
    )
    assert created.status_code == 201

    verify = await client.post(
        f"/api/v1/quests/{seed['gps_quest_id']}/verify",
        json={
            "lat": str(DODAM_LAT),
            "lng": str(DODAM_LNG),
            "photo_url": "/uploads/photos/2026/07/test.jpg",
        },
        headers=headers,
    )
    assert verify.json()["data"]["verified"] is True

    share = await client.post("/api/v1/shares", json={"share_style": "MAP"}, headers=headers)
    assert share.status_code == 201

    response = await client.get(
        "/api/v1/open/regions/danyang/stats", params={"serviceKey": service_key}
    )
    assert response.status_code == 200
    data = response.json()["data"]

    # 허용된 필드만 있는지 우선 확인 — user_id·email 같은 개인 식별 값이 섞이면 실패해야 한다.
    assert set(data.keys()) == _TOP_LEVEL_KEYS
    assert set(data["region"].keys()) == _REGION_KEYS
    assert set(data["visit_stats"].keys()) == _VISIT_STATS_KEYS
    for spot in data["popular_spots"]:
        assert set(spot.keys()) == _POPULAR_SPOT_KEYS
    assert set(data["journey_completion"].keys()) == _JOURNEY_COMPLETION_KEYS
    assert set(data["share_stats"].keys()) == _SHARE_STATS_KEYS

    this_month = datetime.now(ZoneInfo("Asia/Seoul")).strftime("%Y-%m")

    assert data["region"]["slug"] == "danyang"
    assert data["visit_stats"]["total_completed_quests"] == 1
    assert data["visit_stats"]["monthly"] == [{"month": this_month, "count": 1}]
    assert data["popular_spots"][0]["quest_id"] == seed["gps_quest_id"]
    assert data["popular_spots"][0]["completed_count"] == 1
    assert data["dna_distribution"] == {"nature": 1.0}
    assert data["journey_completion"]["started"] == 1
    assert data["journey_completion"]["completed"] == 1
    assert data["journey_completion"]["completion_rate"] == 1.0
    # 이번 여정은 start_date 없이 생성해 평균 완주 소요일수 계산 대상에서 빠진다.
    assert data["journey_completion"]["avg_days_to_complete"] is None
    assert data["verification_method_breakdown"] == {"gps_photo": 1.0}
    assert data["share_stats"] == {"total_shares": 1, "by_style": {"MAP": 1}}


@pytest.mark.asyncio
async def test_region_stats_does_not_leak_other_region_data(client: AsyncClient) -> None:
    """다른 지역(청주시)에서 완료한 퀘스트가 단양군 통계에 섞이지 않아야 한다."""
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)
    service_key = await _issue_key()

    await client.post(
        "/api/v1/journeys",
        json={"region_id": seed["region_id"], "quest_ids": [seed["gps_quest_id"]]},
        headers=headers,
    )
    await client.post(
        f"/api/v1/quests/{seed['gps_quest_id']}/verify",
        json={
            "lat": str(DODAM_LAT),
            "lng": str(DODAM_LNG),
            "photo_url": "/uploads/photos/2026/07/test.jpg",
        },
        headers=headers,
    )

    await client.post(
        "/api/v1/journeys",
        json={
            "region_id": seed["other_region_id"],
            "quest_ids": [seed["other_region_quest_id"]],
        },
        headers=headers,
    )
    other_verify = await client.post(
        f"/api/v1/quests/{seed['other_region_quest_id']}/verify",
        json={
            "lat": "36.6360000",
            "lng": "127.5060000",
            "photo_url": "/uploads/photos/2026/07/photo.jpg",
        },
        headers=headers,
    )
    assert other_verify.json()["data"]["verified"] is True

    response = await client.get(
        "/api/v1/open/regions/danyang/stats", params={"serviceKey": service_key}
    )
    data = response.json()["data"]

    assert data["visit_stats"]["total_completed_quests"] == 1
    assert [spot["quest_id"] for spot in data["popular_spots"]] == [seed["gps_quest_id"]]
    assert data["journey_completion"] == {
        "started": 1,
        "completed": 1,
        "completion_rate": 1.0,
        "avg_days_to_complete": None,
    }
    assert data["verification_method_breakdown"] == {"gps_photo": 1.0}


@pytest.mark.asyncio
async def test_region_stats_requires_valid_service_key(client: AsyncClient) -> None:
    await seed_quest_fixture()

    missing = await client.get("/api/v1/open/regions/danyang/stats")
    assert missing.status_code == 401

    invalid = await client.get(
        "/api/v1/open/regions/danyang/stats", params={"serviceKey": "not-a-real-key"}
    )
    assert invalid.status_code == 401


@pytest.mark.asyncio
async def test_region_stats_rejects_revoked_key(client: AsyncClient) -> None:
    await seed_quest_fixture()
    key = generate_open_api_key()
    async with AsyncSessionLocal() as session:
        record = OpenApiKey(name="회수 대상", key_hash=hash_open_api_key(key), is_active=False)
        session.add(record)
        await session.commit()

    response = await client.get("/api/v1/open/regions/danyang/stats", params={"serviceKey": key})
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_region_stats_unknown_region_returns_404(client: AsyncClient) -> None:
    service_key = await _issue_key()
    response = await client.get(
        "/api/v1/open/regions/nonexistent/stats", params={"serviceKey": service_key}
    )
    assert response.status_code == 404
