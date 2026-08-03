from httpx import AsyncClient


async def test_legacy_catalog_rows_without_stable_keys_remain_visible(
    client: AsyncClient,
) -> None:
    from app.core.database import AsyncSessionLocal
    from app.quests.models import Quest
    from app.regions.models import Region

    async with AsyncSessionLocal() as session:
        region = Region(name="기존 외부 지역", slug=None, area_code="legacy")
        session.add(region)
        await session.flush()
        quest = Quest(
            region_id=region.id,
            client_key=None,
            title="기존 TourAPI 퀘스트",
            category="nature",
            mission_type="quiz",
            mission_meta={"quiz": {"question": "기존 데이터인가?", "answer": "O"}},
        )
        session.add(quest)
        await session.commit()

    regions_response = await client.get("/api/v1/regions")
    quests_response = await client.get(
        "/api/v1/quests",
        params={"region_id": str(region.id)},
    )

    assert regions_response.status_code == 200
    assert any(
        item["id"] == str(region.id) and item["slug"] is None
        for item in regions_response.json()["data"]
    )
    assert quests_response.status_code == 200
    assert quests_response.json()["data"]["items"][0]["client_key"] is None


async def test_regions_expose_stable_flutter_slug(client: AsyncClient) -> None:
    response = await client.get("/api/v1/regions")

    assert response.status_code == 200
    regions = response.json()["data"]
    danyang = next(region for region in regions if region["name"] == "단양군")
    assert danyang["slug"] == "danyang"


async def test_quests_expose_all_stable_keys_and_flutter_mission_types(
    client: AsyncClient,
) -> None:
    regions_response = await client.get("/api/v1/regions")
    danyang = next(
        region for region in regions_response.json()["data"] if region["slug"] == "danyang"
    )

    response = await client.get(
        "/api/v1/quests",
        params={"region_id": danyang["id"], "size": 100},
    )

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["total"] == 20
    assert {item["client_key"] for item in data["items"]} == {
        f"dy{index}" for index in range(1, 21)
    }
    assert {item["mission_type"] for item in data["items"]} == {
        "photo",
        "gps",
        "quiz",
    }
