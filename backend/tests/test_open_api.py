"""지자체 오픈 API 테스트 (docs/specs/070-municipal-open-api)."""

from __future__ import annotations

import re
from datetime import timedelta

import pytest
from httpx import AsyncClient

from app.core.base import now_kst
from app.core.database import AsyncSessionLocal
from app.core.security import generate_open_api_key, hash_open_api_key
from app.open_api.models import OpenApiKey
from tests.helpers import DODAM_LAT, DODAM_LNG, auth_headers, seed_quest_fixture

# 개인 식별 값(user_id·nickname 등)이 실수로 섞여 나오지 않는지 확인하기 위한 명시적 허용 목록.
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


def _period(start_offset_days: int = 0, duration_days: int = 2) -> dict[str, str]:
    start = now_kst().date() + timedelta(days=start_offset_days)
    end = start + timedelta(days=duration_days)
    return {"start_date": start.isoformat(), "end_date": end.isoformat()}


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
        json={
            "region_id": seed["region_id"],
            "quest_ids": [seed["gps_quest_id"]],
            **_period(0, 2),
        },
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
        "/api/v1/open/regions/danyang/stats", headers={"X-Service-Key": service_key}
    )
    assert response.status_code == 200
    data = response.json()["data"]

    # 허용된 필드만 있는지 우선 확인 — user_id·nickname 같은 개인 식별 값이 섞이면 실패해야 한다.
    assert set(data.keys()) == _TOP_LEVEL_KEYS
    assert set(data["region"].keys()) == _REGION_KEYS
    assert set(data["visit_stats"].keys()) == _VISIT_STATS_KEYS
    for spot in data["popular_spots"]:
        assert set(spot.keys()) == _POPULAR_SPOT_KEYS
    assert set(data["journey_completion"].keys()) == _JOURNEY_COMPLETION_KEYS
    assert set(data["share_stats"].keys()) == _SHARE_STATS_KEYS

    assert data["region"]["slug"] == "danyang"
    assert data["visit_stats"]["total_completed_quests"] == 1
    # 실행 시각의 "이번 달"을 테스트에서 다시 계산해 비교하면, 자정 직전 월 경계를 넘는
    # 순간 서버가 기록한 completed_at의 월과 어긋날 수 있다(freezegun 등 시간 고정 없이는
    # 근본적으로 막기 어려움). 월 문자열 형식·건수만 확인해 그 레이스를 아예 피한다.
    monthly = data["visit_stats"]["monthly"]
    assert len(monthly) == 1
    assert monthly[0]["count"] == 1
    assert re.fullmatch(r"\d{4}-\d{2}", monthly[0]["month"])
    assert data["popular_spots"][0]["quest_id"] == seed["gps_quest_id"]
    assert data["popular_spots"][0]["completed_count"] == 1
    assert data["dna_distribution"] == {"nature": 1.0}
    assert data["journey_completion"]["started"] == 1
    assert data["journey_completion"]["completed"] == 0
    assert data["journey_completion"]["completion_rate"] == 0.0
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
        json={
            "region_id": seed["region_id"],
            "quest_ids": [seed["gps_quest_id"]],
            **_period(0, 2),
        },
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
            **_period(10, 2),
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
        "completed": 0,
        "completion_rate": 0.0,
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
