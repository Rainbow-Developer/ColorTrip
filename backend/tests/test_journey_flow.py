"""여정 생성·관리 플로우 테스트 (docs/specs/010-journey/ JRN-01·02)."""

import asyncio
from datetime import datetime, time, timedelta
from uuid import uuid4

from httpx import AsyncClient

from app.core.base import KST, now_kst
from tests.helpers import DODAM_LAT, DODAM_LNG, auth_headers, seed_quest_fixture


def _period(start_offset_days: int = 0, duration_days: int = 2) -> dict[str, str]:
    start = now_kst().date() + timedelta(days=start_offset_days)
    end = start + timedelta(days=duration_days)
    return {"start_date": start.isoformat(), "end_date": end.isoformat()}


def _period_dates(start_offset_days: int = 0, duration_days: int = 2) -> tuple[str, str]:
    period = _period(start_offset_days, duration_days)
    return period["start_date"], period["end_date"]


async def test_create_and_get_journey(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    response = await client.post(
        "/api/v1/journeys",
        json={
            "region_id": seed["region_id"],
            "quest_ids": [seed["gps_quest_id"], seed["quiz_quest_id"]],
            "title": "단양 역사 여행",
            **_period(),
        },
        headers=headers,
    )
    assert response.status_code == 201
    data = response.json()["data"]
    assert data["title"] == "단양 역사 여행"
    assert data["start_date"] == _period()["start_date"]
    assert data["end_date"] == _period()["end_date"]
    assert data["status"] == "in_progress"
    assert data["progress"] == {"completed": 0, "total": 2}
    assert [q["quest_id"] for q in data["quests"]] == [
        seed["gps_quest_id"],
        seed["quiz_quest_id"],
    ]
    assert [q["client_key"] for q in data["quests"]] == [
        "test-gps-quest",
        "test-quiz-quest",
    ]
    assert all(q["progress_status"] is None for q in data["quests"])

    list_response = await client.get("/api/v1/journeys", headers=headers)
    assert list_response.status_code == 200
    list_data = list_response.json()["data"]
    assert list_data["total"] == 1
    assert list_data["items"][0]["id"] == data["id"]
    assert list_data["items"][0]["quest_client_keys"] == [
        "test-gps-quest",
        "test-quiz-quest",
    ]

    detail_response = await client.get(f"/api/v1/journeys/{data['id']}", headers=headers)
    assert detail_response.status_code == 200
    assert detail_response.json()["data"]["id"] == data["id"]


async def _create_journey_with_period(
    client: AsyncClient,
    headers: dict[str, str],
    seed: dict[str, str],
    *,
    end_offset_days: int,
) -> dict:
    """오늘(KST) 기준 상대 기간으로 퀘스트 2개짜리 여정을 만든다 (완료 판정 테스트용)."""
    today = now_kst().date()
    end = today + timedelta(days=end_offset_days)
    start = today
    response = await client.post(
        "/api/v1/journeys",
        json={
            "region_id": seed["region_id"],
            "quest_ids": [seed["quiz_quest_id"], seed["gps_only_quest_id"]],
            "start_date": start.isoformat(),
            "end_date": end.isoformat(),
        },
        headers=headers,
    )
    assert response.status_code == 201
    return response.json()["data"]


async def test_journey_completes_after_end_date_even_without_completed_quest(
    client: AsyncClient, monkeypatch
) -> None:
    """종료일 다음날 00:00 KST부터 completed로 전이한다 (KAN-104)."""
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)
    today = now_kst().date()
    journey = await _create_journey_with_period(client, headers, seed, end_offset_days=0)

    monkeypatch.setattr(
        "app.journeys.service.now_kst",
        lambda: datetime.combine(today + timedelta(days=1), time.min, tzinfo=KST),
    )

    detail = await client.get(f"/api/v1/journeys/{journey['id']}", headers=headers)
    data = detail.json()["data"]
    assert data["progress"] == {"completed": 0, "total": 2}
    assert data["status"] == "completed"
    assert data["completed_at"] is not None

    # 목록도 같은 판정을 쓴다 (조회 시점 동기화).
    listed = await client.get("/api/v1/journeys", headers=headers)
    assert listed.json()["data"]["items"][0]["status"] == "completed"


async def test_journey_stays_in_progress_on_end_date_even_when_all_quests_completed(
    client: AsyncClient,
) -> None:
    """종료일 당일까지는 모든 퀘스트를 완료해도 in_progress다."""
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)
    journey = await _create_journey_with_period(client, headers, seed, end_offset_days=0)

    await client.post(
        f"/api/v1/quests/{seed['quiz_quest_id']}/verify",
        json={"answer": "O"},
        headers=headers,
    )
    await client.post(
        f"/api/v1/quests/{seed['gps_only_quest_id']}/verify",
        json={},
        headers=headers,
    )

    detail = await client.get(f"/api/v1/journeys/{journey['id']}", headers=headers)
    data = detail.json()["data"]
    assert data["progress"] == {"completed": 2, "total": 2}
    assert data["status"] == "in_progress"
    assert data["completed_at"] is None


async def test_journey_stays_in_progress_during_period_with_partial_completion(
    client: AsyncClient,
) -> None:
    """기간이 남아 있으면 완료 수와 무관하게 in_progress다."""
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)
    journey = await _create_journey_with_period(client, headers, seed, end_offset_days=7)

    await client.post(
        f"/api/v1/quests/{seed['quiz_quest_id']}/verify",
        json={"answer": "O"},
        headers=headers,
    )

    detail = await client.get(f"/api/v1/journeys/{journey['id']}", headers=headers)
    assert detail.json()["data"]["status"] == "in_progress"

    await client.post(
        f"/api/v1/quests/{seed['gps_only_quest_id']}/verify",
        json={},  # gps 미션은 좌표를 보내지 않는다 (KAN-77)
        headers=headers,
    )
    completed = await client.get(f"/api/v1/journeys/{journey['id']}", headers=headers)
    assert completed.json()["data"]["status"] == "in_progress"


async def test_create_journey_is_idempotent_per_client_request(
    client: AsyncClient,
) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)
    client_request_id = str(uuid4())
    payload = {
        "client_request_id": client_request_id,
        "region_id": seed["region_id"],
        "quest_ids": [seed["gps_quest_id"]],
        "title": "재시도 안전 여행",
        **_period(),
    }

    first = await client.post("/api/v1/journeys", json=payload, headers=headers)
    retried = await client.post("/api/v1/journeys", json=payload, headers=headers)
    journeys = await client.get("/api/v1/journeys", headers=headers)

    assert first.status_code == 201
    assert retried.status_code == 201
    assert retried.json()["data"]["id"] == first.json()["data"]["id"]
    assert journeys.json()["data"]["total"] == 1


async def test_concurrent_create_journey_requests_converge_to_one_journey(
    client: AsyncClient,
) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)
    payload = {
        "client_request_id": str(uuid4()),
        "region_id": seed["region_id"],
        "quest_ids": [seed["gps_quest_id"]],
        **_period(),
    }

    results = await asyncio.gather(
        client.post("/api/v1/journeys", json=payload, headers=headers),
        client.post("/api/v1/journeys", json=payload, headers=headers),
        return_exceptions=True,
    )

    assert all(not isinstance(result, BaseException) for result in results)
    responses = [result for result in results if not isinstance(result, BaseException)]
    assert all(response.status_code == 201 for response in responses)
    assert len({response.json()["data"]["id"] for response in responses}) == 1


async def test_create_journey_with_already_completed_quest_stays_in_progress(
    client: AsyncClient,
) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    # 여정에 담기 전에 퀘스트를 먼저 완료해 둔다(진행도는 사용자 기준).
    verify = await client.post(
        f"/api/v1/quests/{seed['gps_quest_id']}/verify",
        json={
            "lat": str(DODAM_LAT),
            "lng": str(DODAM_LNG),
            "photo_url": "/uploads/photos/x.jpg",
        },
        headers=headers,
    )
    assert verify.json()["data"]["verified"] is True

    # 이미 완료한 퀘스트만으로 여정을 만들어도 종료일 전에는 in_progress다.
    response = await client.post(
        "/api/v1/journeys",
        json={
            "region_id": seed["region_id"],
            "quest_ids": [seed["gps_quest_id"]],
            **_period(),
        },
        headers=headers,
    )
    assert response.status_code == 201
    data = response.json()["data"]
    assert data["status"] == "in_progress"
    assert data["completed_at"] is None
    assert data["progress"] == {"completed": 1, "total": 1}


async def test_create_journey_requires_dates(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    response = await client.post(
        "/api/v1/journeys",
        json={"region_id": seed["region_id"], "quest_ids": [seed["gps_quest_id"]]},
        headers=headers,
    )
    assert response.status_code == 422


async def test_create_journey_rejects_reversed_dates(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    response = await client.post(
        "/api/v1/journeys",
        json={
            "region_id": seed["region_id"],
            "quest_ids": [seed["gps_quest_id"]],
            "start_date": _period(3, 0)["start_date"],
            "end_date": _period(1, 0)["end_date"],
        },
        headers=headers,
    )
    assert response.status_code == 422
    assert response.json()["code"] == "VALIDATION_ERROR"


async def test_create_journey_rejects_past_period(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)
    yesterday = now_kst().date() - timedelta(days=1)

    response = await client.post(
        "/api/v1/journeys",
        json={
            "region_id": seed["region_id"],
            "quest_ids": [seed["gps_quest_id"]],
            "start_date": (yesterday - timedelta(days=1)).isoformat(),
            "end_date": yesterday.isoformat(),
        },
        headers=headers,
    )

    assert response.status_code == 422
    assert response.json()["code"] == "VALIDATION_ERROR"


async def test_create_journey_allows_overlapping_period(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

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

    overlapped = await client.post(
        "/api/v1/journeys",
        json={
            "region_id": seed["region_id"],
            "quest_ids": [seed["quiz_quest_id"]],
            **_period(2, 2),
        },
        headers=headers,
    )

    assert overlapped.status_code == 201


async def test_update_journey_changes_title_and_dates(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)
    start_date, end_date = _period_dates(10, 2)
    created = await client.post(
        "/api/v1/journeys",
        json={
            "region_id": seed["region_id"],
            "quest_ids": [seed["gps_quest_id"]],
            "title": "처음 여행",
            **_period(0, 2),
        },
        headers=headers,
    )
    journey_id = created.json()["data"]["id"]

    updated = await client.patch(
        f"/api/v1/journeys/{journey_id}",
        json={
            "title": "수정한 여행",
            "start_date": start_date,
            "end_date": end_date,
        },
        headers=headers,
    )

    assert updated.status_code == 200
    data = updated.json()["data"]
    assert data["title"] == "수정한 여행"
    assert data["start_date"] == start_date
    assert data["end_date"] == end_date


async def test_update_journey_rejects_reversed_dates(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)
    created = await client.post(
        "/api/v1/journeys",
        json={
            "region_id": seed["region_id"],
            "quest_ids": [seed["gps_quest_id"]],
            **_period(0, 2),
        },
        headers=headers,
    )
    journey_id = created.json()["data"]["id"]

    response = await client.patch(
        f"/api/v1/journeys/{journey_id}",
        json={
            "start_date": _period(6, 0)["start_date"],
            "end_date": _period(4, 0)["end_date"],
        },
        headers=headers,
    )

    assert response.status_code == 422
    assert response.json()["code"] == "VALIDATION_ERROR"


async def test_update_journey_allows_overlapping_period(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    first = await client.post(
        "/api/v1/journeys",
        json={
            "region_id": seed["region_id"],
            "quest_ids": [seed["gps_quest_id"]],
            **_period(0, 2),
        },
        headers=headers,
    )
    assert first.status_code == 201
    second = await client.post(
        "/api/v1/journeys",
        json={
            "region_id": seed["region_id"],
            "quest_ids": [seed["quiz_quest_id"]],
            **_period(10, 2),
        },
        headers=headers,
    )
    assert second.status_code == 201

    response = await client.patch(
        f"/api/v1/journeys/{second.json()['data']['id']}",
        json=_period(1, 2),
        headers=headers,
    )

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["start_date"] == _period(1, 2)["start_date"]
    assert data["end_date"] == _period(1, 2)["end_date"]


async def test_delete_journey_soft_deletes_linked_records(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)
    created = await client.post(
        "/api/v1/journeys",
        json={
            "region_id": seed["region_id"],
            "quest_ids": [seed["quiz_quest_id"]],
            **_period(0, 2),
        },
        headers=headers,
    )
    journey_id = created.json()["data"]["id"]

    verified = await client.post(
        f"/api/v1/quests/{seed['quiz_quest_id']}/verify",
        json={"answer": "O", "journey_id": journey_id},
        headers=headers,
    )
    assert verified.json()["data"]["verified"] is True
    assert len((await client.get("/api/v1/users/me/timeline", headers=headers)).json()["data"]) == 2

    deleted = await client.delete(f"/api/v1/journeys/{journey_id}", headers=headers)
    assert deleted.status_code == 200

    listed = await client.get("/api/v1/journeys", headers=headers)
    assert listed.json()["data"]["total"] == 0
    detail = await client.get(f"/api/v1/journeys/{journey_id}", headers=headers)
    assert detail.status_code == 404
    timeline = await client.get("/api/v1/users/me/timeline", headers=headers)
    assert timeline.json()["data"] == []
    map_response = await client.get("/api/v1/users/me/map", headers=headers)
    region = next(
        item for item in map_response.json()["data"] if item["region_id"] == seed["region_id"]
    )
    assert region["completed_journey_count"] == 0

    recreated = await client.post(
        "/api/v1/journeys",
        json={
            "region_id": seed["region_id"],
            "quest_ids": [seed["quiz_quest_id"]],
            **_period(0, 2),
        },
        headers=headers,
    )
    new_journey_id = recreated.json()["data"]["id"]
    verified_again = await client.post(
        f"/api/v1/quests/{seed['quiz_quest_id']}/verify",
        json={"answer": "O", "journey_id": new_journey_id},
        headers=headers,
    )
    assert verified_again.status_code == 200
    assert verified_again.json()["data"]["verified"] is True


async def test_delete_journey_keeps_shared_quest_progress_for_other_journey(
    client: AsyncClient,
) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    first = await client.post(
        "/api/v1/journeys",
        json={
            "region_id": seed["region_id"],
            "quest_ids": [seed["quiz_quest_id"]],
            "title": "첫 번째 여행",
            **_period(0, 2),
        },
        headers=headers,
    )
    second = await client.post(
        "/api/v1/journeys",
        json={
            "region_id": seed["region_id"],
            "quest_ids": [seed["quiz_quest_id"]],
            "title": "두 번째 여행",
            **_period(10, 2),
        },
        headers=headers,
    )
    first_id = first.json()["data"]["id"]
    second_id = second.json()["data"]["id"]

    verified = await client.post(
        f"/api/v1/quests/{seed['quiz_quest_id']}/verify",
        json={"answer": "O", "journey_id": first_id},
        headers=headers,
    )
    assert verified.json()["data"]["verified"] is True

    before_delete = await client.get(f"/api/v1/journeys/{second_id}", headers=headers)
    assert before_delete.json()["data"]["status"] == "in_progress"
    assert before_delete.json()["data"]["progress"] == {"completed": 0, "total": 1}

    deleted = await client.delete(f"/api/v1/journeys/{first_id}", headers=headers)
    assert deleted.status_code == 200

    remaining = await client.get(f"/api/v1/journeys/{second_id}", headers=headers)
    assert remaining.status_code == 200
    assert remaining.json()["data"]["status"] == "in_progress"
    assert remaining.json()["data"]["progress"] == {"completed": 1, "total": 1}
    timeline = await client.get("/api/v1/users/me/timeline", headers=headers)
    assert len(timeline.json()["data"]) == 2
    map_response = await client.get("/api/v1/users/me/map", headers=headers)
    region = next(
        item for item in map_response.json()["data"] if item["region_id"] == seed["region_id"]
    )
    assert region["completed_journey_count"] == 1


async def test_verify_shared_quest_requires_explicit_journey(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    for index, title in enumerate(["첫 번째 여행", "두 번째 여행"]):
        created = await client.post(
            "/api/v1/journeys",
            json={
                "region_id": seed["region_id"],
                "quest_ids": [seed["quiz_quest_id"]],
                "title": title,
                **_period(index * 10, 2),
            },
            headers=headers,
        )
        assert created.status_code == 201

    missing_journey = await client.post(
        f"/api/v1/quests/{seed['quiz_quest_id']}/verify",
        json={"answer": "O"},
        headers=headers,
    )
    assert missing_journey.status_code == 422
    assert missing_journey.json()["code"] == "VALIDATION_ERROR"


async def test_create_journey_rejects_cross_region_quest(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    response = await client.post(
        "/api/v1/journeys",
        json={
            "region_id": seed["region_id"],
            "quest_ids": [seed["gps_quest_id"], seed["other_region_quest_id"]],
            **_period(),
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
            **_period(),
        },
        headers=headers,
    )
    assert response.status_code == 404


async def test_add_and_remove_journey_quest(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    created = await client.post(
        "/api/v1/journeys",
        json={
            "region_id": seed["region_id"],
            "quest_ids": [seed["gps_quest_id"]],
            **_period(),
        },
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


async def test_replace_journey_quests_applies_the_final_order_atomically(
    client: AsyncClient,
) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)
    created = await client.post(
        "/api/v1/journeys",
        json={
            "region_id": seed["region_id"],
            "quest_ids": [seed["gps_quest_id"], seed["quiz_quest_id"]],
            **_period(),
        },
        headers=headers,
    )
    journey_id = created.json()["data"]["id"]
    payload = {"quest_ids": [seed["food_quest_id"], seed["quiz_quest_id"]]}

    replaced = await client.put(
        f"/api/v1/journeys/{journey_id}/quests",
        json=payload,
        headers=headers,
    )
    retried = await client.put(
        f"/api/v1/journeys/{journey_id}/quests",
        json=payload,
        headers=headers,
    )

    assert replaced.status_code == 200
    assert retried.status_code == 200
    assert [item["quest_id"] for item in retried.json()["data"]["quests"]] == [
        seed["food_quest_id"],
        seed["quiz_quest_id"],
    ]


async def test_journey_is_private_to_owner(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    owner_headers = await auth_headers(client)
    other_headers = await auth_headers(client, token="kakao-token-unknown")

    created = await client.post(
        "/api/v1/journeys",
        json={
            "region_id": seed["region_id"],
            "quest_ids": [seed["gps_quest_id"]],
            **_period(),
        },
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
