"""퀘스트 진행·인증·추천 테스트 (docs/specs/010-journey/ REC-01·VRF-01~04).

QR 미션 분기(MissionType.QR)는 docs/specs/050-quest-verification/에서 추가됐다.
"""

import asyncio
from uuid import UUID

import pytest
from httpx import AsyncClient

from app.auth.models import User
from app.core.database import AsyncSessionLocal
from app.integrations.vision.base import VisionVerdict
from app.quests.dna import get_user_primary_category
from app.quests.models import Quest
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
        json={
            "lat": "37.5000000",
            "lng": "127.0000000",
            "photo_url": "/uploads/photos/x.jpg",
        },
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


async def test_photo_verify_requires_only_an_uploaded_photo(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    response = await client.post(
        f"/api/v1/quests/{seed['photo_quest_id']}/verify",
        json={"photo_url": "/uploads/photos/2026/07/photo.jpg"},
        headers=headers,
    )

    assert response.status_code == 200
    assert response.json()["data"]["verified"] is True


async def test_photo_verify_rejects_another_users_upload(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    owner_headers = await auth_headers(client)
    other_headers = await auth_headers(client, token="kakao-token-unknown")
    uploaded = await client.post(
        "/api/v1/uploads/photo",
        headers=owner_headers,
        files={"file": ("proof.jpg", b"jpeg", "image/jpeg")},
    )
    assert uploaded.status_code == 201

    response = await client.post(
        f"/api/v1/quests/{seed['photo_quest_id']}/verify",
        json={"photo_url": uploaded.json()["data"]["photo_url"]},
        headers=other_headers,
    )

    assert response.status_code == 422
    assert "본인이 업로드" in response.json()["message"]


async def test_gps_only_verify_requires_location_but_not_photo(
    client: AsyncClient,
) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    response = await client.post(
        f"/api/v1/quests/{seed['gps_only_quest_id']}/verify",
        json={"lat": str(DODAM_LAT), "lng": str(DODAM_LNG)},
        headers=headers,
    )

    assert response.status_code == 200
    assert response.json()["data"]["verified"] is True


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


async def _seed_qr_quest(region_id: str, *, client_key: str | None = "qr-test-1") -> str:
    """QR 미션 퀘스트를 추가 시드한다 (seed_quest_fixture는 010 스펙 소유라 여기서 직접).

    client_key=None이면 QR 인증 정보가 없는 데이터 오류 상황을 만든다.
    """
    from app.core.database import AsyncSessionLocal
    from app.quests.models import Quest

    async with AsyncSessionLocal() as session:
        quest = Quest(
            region_id=UUID(region_id),
            client_key=client_key,
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
    qr_quest_id = await _seed_qr_quest(seed["region_id"], client_key="qr-danyang-1")

    # 다른 퀘스트용 QR로는 실패한다.
    wrong = await client.post(
        f"/api/v1/quests/{qr_quest_id}/verify",
        json={"qr_payload": sign_quest_payload("qr-danyang-2")},
        headers=headers,
    )
    assert wrong.status_code == 200
    assert wrong.json()["data"]["verified"] is False
    assert "이 퀘스트의 QR" in wrong.json()["data"]["reason"]

    # 해당 퀘스트의 서명 QR로 완료된다 — 서명 대상은 client_key다(KAN-75).
    ok = await client.post(
        f"/api/v1/quests/{qr_quest_id}/verify",
        json={"qr_payload": sign_quest_payload("qr-danyang-1")},
        headers=headers,
    )
    assert ok.status_code == 200
    data = ok.json()["data"]
    assert data["verified"] is True
    assert data["reason"] is None
    assert data["progress"]["status"] == "completed"
    assert data["progress"]["completed_at"] is not None


async def test_qr_verify_matches_client_key_not_database_uuid(client: AsyncClient) -> None:
    """UUID로 서명한 QR은 통과하지 않는다 (회귀: KAN-75).

    인쇄 QR을 만드는 scripts/generate_quest_qr.py는 client_key로 서명하는데 서버가 DB
    UUID와 대조하고 있어, 서명이 유효해도 현장 QR이 한 번도 통과할 수 없었다. 두 기준을
    맞바꿔 쓰면 다시 같은 증상이 나므로 UUID 서명은 명시적으로 거절되어야 한다.
    """
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)
    qr_quest_id = await _seed_qr_quest(seed["region_id"], client_key="qr-uuid-check")

    response = await client.post(
        f"/api/v1/quests/{qr_quest_id}/verify",
        json={"qr_payload": sign_quest_payload(qr_quest_id)},
        headers=headers,
    )

    assert response.status_code == 200
    assert response.json()["data"]["verified"] is False


async def test_qr_verify_rejects_quest_without_client_key(client: AsyncClient) -> None:
    """client_key 없이 등록된 QR 퀘스트는 통과시키지 않는다 (fail-closed)."""
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)
    qr_quest_id = await _seed_qr_quest(seed["region_id"], client_key=None)

    response = await client.post(
        f"/api/v1/quests/{qr_quest_id}/verify",
        json={"qr_payload": sign_quest_payload("anything")},
        headers=headers,
    )

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["verified"] is False
    assert "QR 인증 정보" in data["reason"]


async def test_qr_verify_requires_payload(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)
    qr_quest_id = await _seed_qr_quest(seed["region_id"], client_key="qr-no-payload")

    response = await client.post(f"/api/v1/quests/{qr_quest_id}/verify", json={}, headers=headers)
    assert response.status_code == 422


async def test_concurrent_different_quest_completions_update_region_once_each(
    client: AsyncClient,
) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    results = await asyncio.gather(
        client.post(
            f"/api/v1/quests/{seed['photo_quest_id']}/verify",
            json={"photo_url": "/uploads/photos/concurrent.jpg"},
            headers=headers,
        ),
        client.post(
            f"/api/v1/quests/{seed['gps_only_quest_id']}/verify",
            json={"lat": str(DODAM_LAT), "lng": str(DODAM_LNG)},
            headers=headers,
        ),
        return_exceptions=True,
    )

    assert all(not isinstance(result, BaseException) for result in results)
    responses = [result for result in results if not isinstance(result, BaseException)]
    assert all(response.status_code == 200 for response in responses)
    assert all(response.json()["data"]["verified"] is True for response in responses)

    map_response = await client.get("/api/v1/users/me/map", headers=headers)
    region_progress = next(
        item for item in map_response.json()["data"] if item["region_id"] == seed["region_id"]
    )
    assert region_progress["completed_count"] == 2

    timeline = (await client.get("/api/v1/users/me/timeline", headers=headers)).json()["data"]
    assert sum(item["event_type"] == "quest_completed" for item in timeline) == 2
    assert sum(item["event_type"] == "region_colored" for item in timeline) == 1


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
            "photo_url": "/uploads/photos/x.jpg",
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
        json={
            "lat": str(DODAM_LAT),
            "lng": str(DODAM_LNG),
            "photo_url": "/uploads/photos/x.jpg",
        },
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
    assert seed["quiz_quest_id"] in ids
    assert data["items"][0]["category"] == "history"  # 카테고리 일치 우선
    assert data["items"][0]["is_dna_match"] is True
    assert any(not item["is_dna_match"] for item in data["items"])


async def test_recommended_requires_auth(client: AsyncClient) -> None:
    response = await client.get("/api/v1/quests/recommended")
    assert response.status_code == 401


async def test_recommended_uses_saved_user_dna_when_category_is_omitted(
    client: AsyncClient,
) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    response = await client.get(
        "/api/v1/quests/recommended",
        params={"region_id": seed["region_id"]},
        headers=headers,
    )

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["applied_category"] == "nature"
    gps_quest = next(item for item in data["items"] if item["id"] == seed["gps_quest_id"])
    assert gps_quest["is_dna_match"] is True


async def test_unvisited_regions_excludes_regions_with_a_journey(client: AsyncClient) -> None:
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    before = await client.get("/api/v1/regions/unvisited", headers=headers)
    assert before.status_code == 200
    before_items = before.json()["data"]["items"]
    before_ids = [item["id"] for item in before_items]
    assert seed["region_id"] in before_ids
    danyang = next(item for item in before_items if item["id"] == seed["region_id"])
    assert danyang["slug"] == "danyang"
    assert danyang["matching_quest_count"] >= 1
    assert danyang["available_quest_count"] >= danyang["matching_quest_count"]

    await _create_journey(client, headers, seed["region_id"], [seed["gps_quest_id"]])

    after = await client.get("/api/v1/regions/unvisited", headers=headers)
    assert after.status_code == 200
    after_ids = [item["id"] for item in after.json()["data"]["items"]]
    assert seed["region_id"] not in after_ids


async def test_unvisited_regions_requires_auth(client: AsyncClient) -> None:
    assert (await client.get("/api/v1/regions/unvisited")).status_code == 401


async def test_user_primary_category_handles_missing_dna(client: AsyncClient) -> None:
    await seed_quest_fixture()
    headers = await auth_headers(client, token="kakao-token-2")

    me = await client.get("/api/v1/users/me", headers=headers)
    assert me.status_code == 200
    async with AsyncSessionLocal() as session:
        user = await session.get(User, UUID(me.json()["data"]["id"]))
        assert user is not None
        user.dna = None
        await session.commit()
        assert await get_user_primary_category(session, user.id) is None


async def test_recommendations_exclude_quests_without_a_client_key(
    client: AsyncClient,
) -> None:
    """안정 키 없는 퀘스트는 추천 결과·집계·total에서 모두 빠진다.

    Flutter는 정적 카탈로그에 없는 키를 표시할 수 없으므로, 서버가 이런 퀘스트를 내려주면
    화면에는 size보다 적게 뜨는데 페이지네이션 메타데이터는 그렇지 않다고 말하게 된다
    ([065-quest-recommendation-api] 리스크).
    """
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)
    region_id = seed["region_id"]

    params = {"region_id": region_id, "size": 100}
    before = await client.get("/api/v1/quests/recommended", params=params, headers=headers)
    assert before.status_code == 200
    before_total = before.json()["data"]["total"]

    unvisited_before = await client.get("/api/v1/regions/unvisited", headers=headers)
    assert unvisited_before.status_code == 200
    danyang_before = next(
        item for item in unvisited_before.json()["data"]["items"] if item["id"] == region_id
    )

    # TourAPI 등 카탈로그 밖에서 유입된 안정 키 없는 퀘스트를 같은 지역에 심는다.
    async with AsyncSessionLocal() as session:
        session.add(
            Quest(
                region_id=UUID(region_id),
                client_key=None,
                title="안정 키 없는 레거시 퀘스트",
                category="nature",
                mission_type="photo",
            )
        )
        await session.commit()

    after = await client.get("/api/v1/quests/recommended", params=params, headers=headers)
    assert after.status_code == 200
    after_data = after.json()["data"]
    assert after_data["total"] == before_total
    assert all(item["client_key"] is not None for item in after_data["items"])

    unvisited_after = await client.get("/api/v1/regions/unvisited", headers=headers)
    assert unvisited_after.status_code == 200
    danyang_after = next(
        item for item in unvisited_after.json()["data"]["items"] if item["id"] == region_id
    )
    assert danyang_after["available_quest_count"] == danyang_before["available_quest_count"]
    assert danyang_after["matching_quest_count"] == danyang_before["matching_quest_count"]


# --- 사진 비전 판정 (KAN-73 — 저장된 사진을 읽어 판정) ---


class _FixedVisionJudge:
    """지정한 판정 결과만 돌려주는 대역 — 실제 모델 호출 없이 분기를 검증한다."""

    def __init__(self, verdict: VisionVerdict) -> None:
        self._verdict = verdict
        self.calls = 0

    async def judge(self, image_bytes: bytes, mime_type: str, prompt: str) -> VisionVerdict:
        self.calls += 1
        assert image_bytes, "저장된 사진 바이트가 판정기까지 전달돼야 한다"
        assert prompt, "서버가 만든 판정 프롬프트가 있어야 한다"
        return self._verdict


async def test_photo_verify_returns_vision_verdict_in_response(client: AsyncClient) -> None:
    """사진 인증 응답에 판정 상세(신뢰도·사유·제공자)가 함께 내려온다."""
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    response = await client.post(
        f"/api/v1/quests/{seed['photo_quest_id']}/verify",
        json={"photo_url": "/uploads/photos/2026/07/photo.jpg"},
        headers=headers,
    )
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["verified"] is True
    # 키 미설정 + APP_ENV=test → 스텁 판정(통과)
    assert data["photo_verdict"]["passed"] is True
    assert data["photo_verdict"]["provider"] == "stub"
    assert data["photo_verdict"]["reason"]


async def test_photo_verify_rejected_by_vision_does_not_complete(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    """비전 판정이 거절하면 완료 처리하지 않고 판정 사유를 돌려준다."""
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)
    judge = _FixedVisionJudge(
        VisionVerdict(
            passed=False,
            confidence=0.1,
            reason="사진에서 퀘스트 장소를 확인할 수 없습니다.",
            provider="gemini",
        )
    )
    monkeypatch.setattr("app.verifications.service.get_vision_judge", lambda: judge)

    response = await client.post(
        f"/api/v1/quests/{seed['photo_quest_id']}/verify",
        json={"photo_url": "/uploads/photos/2026/07/photo.jpg"},
        headers=headers,
    )
    assert response.status_code == 200
    data = response.json()["data"]
    assert judge.calls == 1
    assert data["verified"] is False
    assert data["reason"] == "사진에서 퀘스트 장소를 확인할 수 없습니다."
    assert data["photo_verdict"]["passed"] is False
    assert data["progress"]["status"] != "completed"

    # 완료되지 않았으므로 진행 목록에도 완료로 남지 않는다.
    progress = await client.get("/api/v1/users/me/progress", headers=headers)
    statuses = [item["status"] for item in progress.json()["data"]["items"]]
    assert "completed" not in statuses


async def test_photo_verify_rejects_when_stored_photo_is_missing(client: AsyncClient) -> None:
    """업로드 기록은 있어도 저장된 파일을 읽지 못하면 거절한다(fail-closed)."""
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    # 소유권 기록만 만들고 파일은 만들지 않은 photo_url.
    from app.auth.models import User as _User
    from app.core.database import AsyncSessionLocal as _Session
    from app.uploads.models import UploadedPhoto as _UploadedPhoto

    me = await client.get("/api/v1/users/me", headers=headers)
    async with _Session() as session:
        user = await session.get(_User, UUID(me.json()["data"]["id"]))
        assert user is not None
        session.add(_UploadedPhoto(user_id=user.id, photo_url="/uploads/photos/ghost.jpg"))
        await session.commit()

    response = await client.post(
        f"/api/v1/quests/{seed['photo_quest_id']}/verify",
        json={"photo_url": "/uploads/photos/ghost.jpg"},
        headers=headers,
    )
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["verified"] is False
    assert "사진" in data["reason"]
    assert data["progress"]["status"] != "completed"


async def test_gps_photo_out_of_radius_skips_vision_judgement(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    """반경을 벗어나면 판정 비용을 쓰지 않고 거절한다."""
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)
    judge = _FixedVisionJudge(
        VisionVerdict(passed=True, confidence=1.0, reason="통과", provider="gemini")
    )
    monkeypatch.setattr("app.verifications.service.get_vision_judge", lambda: judge)

    response = await client.post(
        f"/api/v1/quests/{seed['gps_quest_id']}/verify",
        json={
            "lat": "37.5665000",
            "lng": "126.9780000",
            "photo_url": "/uploads/photos/x.jpg",
        },
        headers=headers,
    )
    assert response.json()["data"]["verified"] is False
    assert judge.calls == 0


async def test_verify_rejects_oversized_qr_payload(client: AsyncClient) -> None:
    """과대 QR 페이로드는 파싱 전에 422로 막는다(판정 전용 엔드포인트에서 옮겨온 보호).

    본문 검증이 핸들러보다 먼저 도므로 어떤 퀘스트 id로 보내도 422다.
    """
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)

    response = await client.post(
        f"/api/v1/quests/{seed['photo_quest_id']}/verify",
        json={"qr_payload": "colortrip:quest:" + "0" * 500},
        headers=headers,
    )
    assert response.status_code == 422


async def test_photo_verify_closes_transaction_before_vision_call(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    """비전 판정 중에는 요청 세션이 트랜잭션을 열고 있지 않아야 한다.

    열어둔 채 외부 API(최대 30초)를 기다리면 커넥션이 idle-in-transaction으로 묶여,
    판정이 느릴 때 풀이 소진되고 사진 인증과 무관한 API까지 함께 실패한다.
    """
    from app.core import database

    created_sessions = []
    original_factory = database.AsyncSessionLocal

    def tracking_factory(*args: object, **kwargs: object):
        session = original_factory(*args, **kwargs)
        created_sessions.append(session)
        return session

    monkeypatch.setattr(database, "AsyncSessionLocal", tracking_factory)

    open_transactions: list[bool] = []

    class _ProbeJudge:
        async def judge(self, image_bytes: bytes, mime_type: str, prompt: str) -> VisionVerdict:
            # 판정 시점(외부 호출 자리)에 열린 트랜잭션이 있는지 기록한다.
            open_transactions.append(any(s.in_transaction() for s in created_sessions))
            return VisionVerdict(passed=True, confidence=0.9, reason="통과", provider="gemini")

    monkeypatch.setattr("app.verifications.service.get_vision_judge", lambda: _ProbeJudge())

    seed = await seed_quest_fixture()
    headers = await auth_headers(client)
    response = await client.post(
        f"/api/v1/quests/{seed['photo_quest_id']}/verify",
        json={"photo_url": "/uploads/photos/2026/07/photo.jpg"},
        headers=headers,
    )

    assert response.json()["data"]["verified"] is True
    assert open_transactions == [False], (
        f"판정 중 열린 트랜잭션이 없어야 한다 (기록: {open_transactions!r})"
    )
