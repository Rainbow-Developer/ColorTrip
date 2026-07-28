from httpx import AsyncClient


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
