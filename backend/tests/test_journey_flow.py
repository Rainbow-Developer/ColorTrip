"""여정 생성·관리 플로우 테스트 (docs/specs/010-journey/ JRN-01·02)."""

from httpx import AsyncClient

from tests.helpers import auth_headers, seed_quest_fixture


async def test_create_and_get_journey(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    response = await client.post(
        "/api/v1/journeys",
        json={
            "region_id": seed["region_id"],
            "quest_ids": [seed["gps_quest_id"], seed["quiz_quest_id"]],
            "title": "단양 역사 여행",
        },
        headers=headers,
    )
    assert response.status_code == 201
    data = response.json()["data"]
    assert data["title"] == "단양 역사 여행"
    assert data["status"] == "in_progress"
    assert data["progress"] == {"completed": 0, "total": 2}
    assert [q["quest_id"] for q in data["quests"]] == [
        seed["gps_quest_id"],
        seed["quiz_quest_id"],
    ]
    assert all(q["progress_status"] is None for q in data["quests"])

    list_response = await client.get("/api/v1/journeys", headers=headers)
    assert list_response.status_code == 200
    list_data = list_response.json()["data"]
    assert list_data["total"] == 1
    assert list_data["items"][0]["id"] == data["id"]

    detail_response = await client.get(f"/api/v1/journeys/{data['id']}", headers=headers)
    assert detail_response.status_code == 200
    assert detail_response.json()["data"]["id"] == data["id"]


async def test_create_journey_rejects_cross_region_quest(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    response = await client.post(
        "/api/v1/journeys",
        json={
            "region_id": seed["region_id"],
            "quest_ids": [seed["gps_quest_id"], seed["other_region_quest_id"]],
        },
        headers=headers,
    )
    assert response.status_code == 422
    assert response.json()["code"] == "VALIDATION_ERROR"


async def test_create_journey_rejects_unknown_quest(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    response = await client.post(
        "/api/v1/journeys",
        json={
            "region_id": seed["region_id"],
            "quest_ids": ["01900000-0000-7000-8000-000000000000"],
        },
        headers=headers,
    )
    assert response.status_code == 404


async def test_add_and_remove_journey_quest(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    created = await client.post(
        "/api/v1/journeys",
        json={"region_id": seed["region_id"], "quest_ids": [seed["gps_quest_id"]]},
        headers=headers,
    )
    journey_id = created.json()["data"]["id"]

    # 추가
    added = await client.post(
        f"/api/v1/journeys/{journey_id}/quests",
        json={"quest_id": seed["food_quest_id"]},
        headers=headers,
    )
    assert added.status_code == 200
    assert added.json()["data"]["progress"]["total"] == 2

    # 중복 추가 → 409
    duplicated = await client.post(
        f"/api/v1/journeys/{journey_id}/quests",
        json={"quest_id": seed["food_quest_id"]},
        headers=headers,
    )
    assert duplicated.status_code == 409

    # 타지역 퀘스트 추가 → 422
    cross_region = await client.post(
        f"/api/v1/journeys/{journey_id}/quests",
        json={"quest_id": seed["other_region_quest_id"]},
        headers=headers,
    )
    assert cross_region.status_code == 422

    # 제거
    removed = await client.delete(
        f"/api/v1/journeys/{journey_id}/quests/{seed['food_quest_id']}",
        headers=headers,
    )
    assert removed.status_code == 200
    assert removed.json()["data"]["progress"]["total"] == 1

    # 재제거 → 404
    removed_again = await client.delete(
        f"/api/v1/journeys/{journey_id}/quests/{seed['food_quest_id']}",
        headers=headers,
    )
    assert removed_again.status_code == 404

    # 재추가(soft delete 복원) → 200
    restored = await client.post(
        f"/api/v1/journeys/{journey_id}/quests",
        json={"quest_id": seed["food_quest_id"]},
        headers=headers,
    )
    assert restored.status_code == 200
    assert restored.json()["data"]["progress"]["total"] == 2


async def test_journey_is_private_to_owner(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    owner_headers = await auth_headers(client)
    other_headers = await auth_headers(client, token="kakao-token-unknown")

    created = await client.post(
        "/api/v1/journeys",
        json={"region_id": seed["region_id"], "quest_ids": [seed["gps_quest_id"]]},
        headers=owner_headers,
    )
    journey_id = created.json()["data"]["id"]

    response = await client.get(f"/api/v1/journeys/{journey_id}", headers=other_headers)
    assert response.status_code == 404

    my_list = await client.get("/api/v1/journeys", headers=other_headers)
    assert my_list.json()["data"]["total"] == 0


async def test_journey_requires_auth(client: AsyncClient) -> None:
    response = await client.get("/api/v1/journeys")
    assert response.status_code == 401
