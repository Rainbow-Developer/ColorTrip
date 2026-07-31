"""퀘스트 진행·인증·추천 테스트 (docs/specs/010-journey/ REC-01·VRF-01~04).

QR 미션 분기(MissionType.QR)는 docs/specs/050-quest-verification/에서 추가됐다.
"""

from uuid import UUID

from httpx import AsyncClient

from app.verifications.service import sign_quest_payload
from tests.helpers import DODAM_LAT, DODAM_LNG, auth_headers, seed_quest_fixture


async def _create_journey(
    client: AsyncClient, headers: dict[str, str], region_id: str, quest_ids: list[str]
) -> str:
    response = await client.post(
        "/api/v1/journeys",
        json={"region_id": region_id, "quest_ids": quest_ids},
        headers=headers,
    )
    assert response.status_code == 201
    return response.json()["data"]["id"]


async def test_start_quest_is_idempotent(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    first = await client.post(f"/api/v1/quests/{seed['gps_quest_id']}/start", headers=headers)
    assert first.status_code == 201
    assert first.json()["data"]["status"] == "in_progress"

    second = await client.post(f"/api/v1/quests/{seed['gps_quest_id']}/start", headers=headers)
    assert second.status_code == 201
    assert second.json()["data"]["id"] == first.json()["data"]["id"]


async def test_gps_verify_completes_quest_and_journey(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)
    journey_id = await _create_journey(client, headers, seed["region_id"], [seed["gps_quest_id"]])

    response = await client.post(
        f"/api/v1/quests/{seed['gps_quest_id']}/verify",
        json={
            "journey_id": journey_id,
            "lat": str(DODAM_LAT),
            "lng": str(DODAM_LNG),
            "photo_url": "/uploads/photos/2026/07/test.jpg",
        },
        headers=headers,
    )
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["verified"] is True
    assert data["progress"]["status"] == "completed"
    assert data["progress"]["completed_at"] is not None

    # 여정의 모든 퀘스트가 완료됐으므로 여정도 자동 완료된다.
    journey = await client.get(f"/api/v1/journeys/{journey_id}", headers=headers)
    journey_data = journey.json()["data"]
    assert journey_data["status"] == "completed"
    assert journey_data["completed_at"] is not None
    assert journey_data["progress"] == {"completed": 1, "total": 1}

    # 내 진행 목록에서도 완료로 보인다.
    progress = await client.get(
        "/api/v1/users/me/progress", params={"status": "completed"}, headers=headers
    )
    items = progress.json()["data"]["items"]
    assert len(items) == 1
    assert items[0]["quest_id"] == seed["gps_quest_id"]
    assert items[0]["quest_title"] == "도담삼봉 인증샷"


async def test_gps_verify_out_of_radius_fails(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    response = await client.post(
        f"/api/v1/quests/{seed['gps_quest_id']}/verify",
        json={"lat": "37.5000000", "lng": "127.0000000", "photo_url": "/uploads/x.jpg"},
        headers=headers,
    )
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["verified"] is False
    assert "반경" in data["reason"]
    assert data["progress"]["status"] == "in_progress"


async def test_gps_verify_requires_coords_and_photo(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    response = await client.post(
        f"/api/v1/quests/{seed['gps_quest_id']}/verify",
        json={"lat": str(DODAM_LAT)},
        headers=headers,
    )
    assert response.status_code == 422


async def test_quiz_verify(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    wrong = await client.post(
        f"/api/v1/quests/{seed['quiz_quest_id']}/verify",
        json={"answer": "X"},
        headers=headers,
    )
    assert wrong.json()["data"]["verified"] is False

    # 공백·대소문자는 정규화해 비교한다 (정답 "O")
    correct = await client.post(
        f"/api/v1/quests/{seed['quiz_quest_id']}/verify",
        json={"answer": " o "},
        headers=headers,
    )
    assert correct.json()["data"]["verified"] is True
    assert correct.json()["data"]["progress"]["status"] == "completed"


async def _seed_qr_quest(region_id: str) -> str:
    """QR 미션 퀘스트를 추가 시드한다 (seed_quest_fixture는 010 스펙 소유라 여기서 직접)."""
    from app.core.database import AsyncSessionLocal
    from app.quests.models import Quest

    async with AsyncSessionLocal() as session:
        quest = Quest(
            region_id=UUID(region_id),
            title="수양개빛터널 현장 QR",
            category="activity",
            mission_type="qr",
        )
        session.add(quest)
        await session.commit()
        return str(quest.id)


async def test_qr_verify_completes_quest(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)
    qr_quest_id = await _seed_qr_quest(seed["region_id"])

    # 다른 퀘스트용 QR로는 실패한다.
    wrong = await client.post(
        f"/api/v1/quests/{qr_quest_id}/verify",
        json={"qr_payload": sign_quest_payload(seed["gps_quest_id"])},
        headers=headers,
    )
    assert wrong.status_code == 200
    assert wrong.json()["data"]["verified"] is False
    assert "이 퀘스트의 QR" in wrong.json()["data"]["reason"]

    # 해당 퀘스트의 서명 QR로 완료된다.
    ok = await client.post(
        f"/api/v1/quests/{qr_quest_id}/verify",
        json={"qr_payload": sign_quest_payload(qr_quest_id)},
        headers=headers,
    )
    assert ok.status_code == 200
    data = ok.json()["data"]
    assert data["verified"] is True
    assert data["reason"] is None
    assert data["progress"]["status"] == "completed"
    assert data["progress"]["completed_at"] is not None


async def test_qr_verify_requires_payload(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)
    qr_quest_id = await _seed_qr_quest(seed["region_id"])

    response = await client.post(f"/api/v1/quests/{qr_quest_id}/verify", json={}, headers=headers)
    assert response.status_code == 422


async def test_verify_completed_quest_conflicts(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    await client.post(
        f"/api/v1/quests/{seed['quiz_quest_id']}/verify",
        json={"answer": "O"},
        headers=headers,
    )
    again = await client.post(
        f"/api/v1/quests/{seed['quiz_quest_id']}/verify",
        json={"answer": "O"},
        headers=headers,
    )
    assert again.status_code == 409

    start_again = await client.post(
        f"/api/v1/quests/{seed['quiz_quest_id']}/start", headers=headers
    )
    assert start_again.status_code == 409


async def test_verify_with_foreign_journey_rejected(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    owner_headers = await auth_headers(client)
    other_headers = await auth_headers(client, token="kakao-token-unknown")
    journey_id = await _create_journey(
        client, owner_headers, seed["region_id"], [seed["gps_quest_id"]]
    )

    response = await client.post(
        f"/api/v1/quests/{seed['gps_quest_id']}/verify",
        json={
            "journey_id": journey_id,
            "lat": str(DODAM_LAT),
            "lng": str(DODAM_LNG),
            "photo_url": "/uploads/x.jpg",
        },
        headers=other_headers,
    )
    assert response.status_code == 404


async def test_recommended_excludes_completed_and_sorts_by_category(
    client: AsyncClient,
) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    # nature 퀘스트를 완료하면 추천에서 빠진다.
    await client.post(
        f"/api/v1/quests/{seed['gps_quest_id']}/verify",
        json={"lat": str(DODAM_LAT), "lng": str(DODAM_LNG), "photo_url": "/uploads/x.jpg"},
        headers=headers,
    )

    response = await client.get(
        "/api/v1/quests/recommended",
        params={"region_id": seed["region_id"], "category": "history"},
        headers=headers,
    )
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["applied_category"] == "history"
    ids = [item["id"] for item in data["items"]]
    assert seed["gps_quest_id"] not in ids  # 완료 퀘스트 제외
    assert ids[0] == seed["quiz_quest_id"]  # 카테고리 일치 우선
    assert data["items"][0]["is_dna_match"] is True
    assert data["items"][1]["is_dna_match"] is False


async def test_recommended_requires_auth(client: AsyncClient) -> None:
    response = await client.get("/api/v1/quests/recommended")
    assert response.status_code == 401
