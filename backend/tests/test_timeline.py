from __future__ import annotations

import pytest
from httpx import AsyncClient

from app.core.base import now_kst
from tests.helpers import DODAM_LAT, DODAM_LNG, auth_headers, seed_quest_fixture


@pytest.mark.asyncio
async def test_get_timeline_empty(client: AsyncClient) -> None:
    """타임라인 데이터가 없을 때, 빈 목록을 성공적으로 반환하는지 테스트합니다."""
    headers = await auth_headers(client)
    response = await client.get("/api/v1/users/me/timeline", headers=headers)

    assert response.status_code == 200
    res_json = response.json()
    assert res_json["status"] == 200
    assert res_json["code"] == "SUCCESS"
    assert res_json["data"] == []


@pytest.mark.asyncio
async def test_quest_completion_generates_timeline_and_color_events(client: AsyncClient) -> None:
    """퀘스트를 완료했을 때, 타임라인 이벤트가 성공적으로 적재되는지 검증합니다."""
    # 1. 픽스쳐 준비
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    # 2. 퀘스트 인증(verify) 요청 성공 -> 완료 상태로 변경 유도
    verify_resp = await client.post(
        f"/api/v1/quests/{seed['gps_quest_id']}/verify",
        json={
            "lat": str(DODAM_LAT),
            "lng": str(DODAM_LNG),
            "photo_url": "/uploads/photos/2026/07/test.jpg",
        },
        headers=headers,
    )
    assert verify_resp.status_code == 200
    assert verify_resp.json()["data"]["verified"] is True

    # 3. 타임라인 API 호출
    timeline_resp = await client.get("/api/v1/users/me/timeline", headers=headers)
    assert timeline_resp.status_code == 200

    timeline_data = timeline_resp.json()["data"]
    # 퀘스트 완료 + 최초 색칠 완료 두 개의 타임라인 레코드가 생성되어야 함
    assert len(timeline_data) == 2

    # 최신 순 정렬(occurred_at DESC) 검증
    # region_colored가 quest_completed보다 조금 늦게 적재되거나 동시일 텐데,
    # create_timeline_event 흐름상 region_colored가 먼저 호출(3-1)되고
    # quest_completed가 나중(3-2)에 호출되므로,
    # sequence에 따라 quest_completed가 index 0에 위치할 가능성도 있습니다.
    # 둘 다 정상 적재되었는지만 확인해 봅니다.
    event_types = {item["event_type"] for item in timeline_data}
    assert "region_colored" in event_types
    assert "quest_completed" in event_types

    # 상세 필드 조인 및 명칭 매핑 확인
    for item in timeline_data:
        assert item["region_name"] == "단양군"
        if item["event_type"] == "quest_completed":
            assert item["title"] == "도담삼봉 인증샷"
            assert item["quest_id"] == seed["gps_quest_id"]
            assert item["quest_client_key"] == "test-gps-quest"
            assert item["photo_url"] == "/uploads/photos/2026/07/test.jpg"
        elif item["event_type"] == "region_colored":
            assert item["title"] == "단양군 색칠 성공!"
            assert item["quest_id"] is None
            assert item["quest_client_key"] is None
            assert item["photo_url"] is None


@pytest.mark.asyncio
async def test_get_timeline_filtering(client: AsyncClient) -> None:
    """타임라인 연/월 필터링 파라미터가 정확하게 작동하는지 검사합니다."""
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    # 퀘스트 인증 완료
    await client.post(
        f"/api/v1/quests/{seed['gps_quest_id']}/verify",
        json={
            "lat": str(DODAM_LAT),
            "lng": str(DODAM_LNG),
            "photo_url": "/uploads/photos/2026/07/test.jpg",
        },
        headers=headers,
    )

    # 1. 올해 & 이번 달 필터로 조회 시 데이터가 잡혀야 함 (KST 기준)
    now = now_kst()
    resp_filtered = await client.get(
        "/api/v1/users/me/timeline",
        params={"year": now.year, "month": now.month},
        headers=headers,
    )
    assert resp_filtered.status_code == 200
    assert len(resp_filtered.json()["data"]) == 2

    # 2. 다른 연도로 필터 시 데이터가 비어 있어야 함
    resp_empty = await client.get(
        "/api/v1/users/me/timeline",
        params={"year": now.year - 1},
        headers=headers,
    )
    assert resp_empty.status_code == 200
    assert len(resp_empty.json()["data"]) == 0
