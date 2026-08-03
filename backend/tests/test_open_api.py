"""지자체 오픈 API 테스트 (docs/specs/070-municipal-open-api)."""

from __future__ import annotations

import pytest
from httpx import AsyncClient

from app.core.database import AsyncSessionLocal
from app.core.security import generate_open_api_key, hash_open_api_key
from app.open_api.models import OpenApiKey
from tests.helpers import DODAM_LAT, DODAM_LNG, auth_headers, seed_quest_fixture


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

    assert data["region"]["slug"] == "danyang"
    assert data["visit_stats"]["total_completed_quests"] == 1
    assert data["popular_spots"][0]["quest_id"] == seed["gps_quest_id"]
    assert data["popular_spots"][0]["completed_count"] == 1
    assert data["dna_distribution"] == {"nature": 1.0}
    assert data["journey_completion"]["started"] == 1
    assert data["journey_completion"]["completed"] == 1
    assert data["journey_completion"]["completion_rate"] == 1.0
    assert data["verification_method_breakdown"] == {"gps_photo": 1.0}
    assert data["share_stats"] == {"total_shares": 1, "by_style": {"MAP": 1}}


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
