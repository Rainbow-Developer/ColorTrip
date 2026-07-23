from __future__ import annotations

import pytest
from httpx import AsyncClient

from tests.helpers import DODAM_LAT, DODAM_LNG, auth_headers, seed_quest_fixture


@pytest.mark.asyncio
async def test_get_my_share_summary(client: AsyncClient) -> None:
    """내 여행 지도 진행률, DNA, 색칠된 시·군 요약 조회가 정상 동작하는지 테스트합니다."""
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    # 퀘스트 완료를 통해 지도 1개 영역 색칠
    await client.post(
        f"/api/v1/quests/{seed['gps_quest_id']}/verify",
        json={
            "lat": str(DODAM_LAT),
            "lng": str(DODAM_LNG),
            "photo_url": "/uploads/photos/2026/07/test.jpg",
        },
        headers=headers,
    )

    response = await client.get("/api/v1/users/me/share-summary", headers=headers)
    assert response.status_code == 200
    res_json = response.json()
    assert res_json["code"] == "SUCCESS"

    data = res_json["data"]
    assert data["completed_region_count"] == 1
    assert data["total_region_count"] >= 1
    assert data["progress_percentage"] > 0
    assert len(data["colored_regions"]) == 1
    assert data["colored_regions"][0]["name"] == "단양군"


@pytest.mark.asyncio
async def test_create_share_card(client: AsyncClient) -> None:
    """MAP_AND_DNA, MAP, DNA 스타일별 공유 카드 생성 API를 테스트합니다."""
    headers = await auth_headers(client)

    # 1. MAP_AND_DNA 생성
    res1 = await client.post(
        "/api/v1/shares",
        json={"share_style": "MAP_AND_DNA"},
        headers=headers,
    )
    assert res1.status_code == 201
    data1 = res1.json()["data"]
    assert len(data1["share_code"]) == 8
    assert data1["share_style"] == "MAP_AND_DNA"
    assert data1["share_code"] in data1["share_url"]

    # 2. MAP 생성
    res2 = await client.post(
        "/api/v1/shares",
        json={"share_style": "MAP"},
        headers=headers,
    )
    assert res2.status_code == 201
    assert res2.json()["data"]["share_style"] == "MAP"

    # 3. DNA 생성
    res3 = await client.post(
        "/api/v1/shares",
        json={"share_style": "DNA"},
        headers=headers,
    )
    assert res3.status_code == 201
    assert res3.json()["data"]["share_style"] == "DNA"

    # 4. 잘못된 스타일 전달 시 422 에러
    res_invalid = await client.post(
        "/api/v1/shares",
        json={"share_style": "INVALID_STYLE"},
        headers=headers,
    )
    assert res_invalid.status_code == 422


@pytest.mark.asyncio
async def test_get_public_share_card(client: AsyncClient) -> None:
    """비인증(Public) 상태에서 공유 숏코드를 통해 카드를 조회하는 API를 테스트합니다."""
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    # 퀘스트 완료
    await client.post(
        f"/api/v1/quests/{seed['gps_quest_id']}/verify",
        json={
            "lat": str(DODAM_LAT),
            "lng": str(DODAM_LNG),
            "photo_url": "/uploads/photos/2026/07/test.jpg",
        },
        headers=headers,
    )

    # 공유 카드 생성
    share_res = await client.post(
        "/api/v1/shares",
        json={"share_style": "MAP_AND_DNA"},
        headers=headers,
    )
    share_code = share_res.json()["data"]["share_code"]

    # 비인증 상태(headers 미포함)로 공개 조회
    public_res = await client.get(f"/api/v1/shares/{share_code}")
    assert public_res.status_code == 200
    p_data = public_res.json()["data"]

    assert p_data["share_code"] == share_code
    assert p_data["share_style"] == "MAP_AND_DNA"
    assert p_data["completed_region_count"] == 1
    assert len(p_data["colored_regions"]) == 1
    assert p_data["colored_regions"][0]["name"] == "단양군"


@pytest.mark.asyncio
async def test_get_public_share_card_not_found(client: AsyncClient) -> None:
    """존재하지 않는 숏코드 조회 시 404 에러를 반환하는지 테스트합니다."""
    response = await client.get("/api/v1/shares/nonexist")
    assert response.status_code == 404
