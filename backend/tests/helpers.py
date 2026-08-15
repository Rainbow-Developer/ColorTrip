from __future__ import annotations

from decimal import Decimal
from typing import Any
from uuid import UUID

from httpx import AsyncClient


async def login(client: AsyncClient, token: str = "kakao-token-1") -> dict[str, Any]:
    response = await client.post(
        "/api/v1/auth/login/social",
        json={"provider": "kakao", "access_token": token},
    )
    assert response.status_code == 200
    return response.json()["data"]


async def auth_headers(
    client: AsyncClient,
    token: str = "kakao-token-1",
    *,
    complete: bool = True,
) -> dict[str, str]:
    data = await login(client, token)
    return await complete_auth_headers(client, data, complete=complete)


async def complete_auth_headers(
    client: AsyncClient,
    data: dict[str, Any],
    *,
    complete: bool = True,
) -> dict[str, str]:
    headers = {"Authorization": f"Bearer {data['access_token']}"}
    response = await client.put(
        "/api/v1/users/me/onboarding-profile",
        headers=headers,
        json={
            "nickname": data["user"]["nickname"] or "테스트 사용자",
            "birth_date": "2000-01-01",
            "terms_agreed": True,
            "privacy_agreed": True,
            "marketing_agreed": False,
        },
    )
    assert response.status_code == 200

    if complete:
        from app.auth.models import User
        from app.core.database import AsyncSessionLocal
        from app.uploads.models import UploadedPhoto

        async with AsyncSessionLocal() as session:
            user = await session.get(User, UUID(data["user"]["id"]))
            assert user is not None
            user.dna = "nature"
            # 기존 인증 테스트의 사진 URL은 실제 업로드가 선행된 상태를 표현한다.
            # 사진 소유권 제약 아래에서도 해당 fixture 의도를 유지한다.
            session.add_all(
                UploadedPhoto(user_id=user.id, photo_url=photo_url)
                for photo_url in FIXTURE_PHOTO_URLS
            )
            await session.commit()

        # 사진 인증은 저장된 사진을 읽어 판정하므로(KAN-73) 파일도 함께 만들어 둔다.
        await seed_fixture_photo_files()
    return headers


# 인증 테스트가 photo_url로 참조하는 사진들 — DB 레코드와 실제 파일을 함께 준비한다.
FIXTURE_PHOTO_URLS = (
    "/uploads/photos/x.jpg",
    "/uploads/photos/legacy.jpg",
    "/uploads/photos/concurrent.jpg",
    "/uploads/photos/2026/07/test.jpg",
    "/uploads/photos/2026/07/photo.jpg",
)

# 최소 PNG 헤더 — 스텁 판정은 내용을 보지 않지만 이미지 바이트 형태는 유지한다.
FIXTURE_PHOTO_BYTES = b"\x89PNG\r\n\x1a\n" + b"0" * 32


async def seed_fixture_photo_files() -> None:
    """[FIXTURE_PHOTO_URLS]에 대응하는 파일을 테스트 스토리지에 만든다."""
    from app.uploads.storage import get_photo_storage

    storage = get_photo_storage()
    for photo_url in FIXTURE_PHOTO_URLS:
        await storage.save(photo_url.removeprefix("/uploads/"), FIXTURE_PHOTO_BYTES, "image/png")


# 도담삼봉 기준 좌표 — GPS 인증 테스트용
DODAM_LAT = Decimal("36.9852000")
DODAM_LNG = Decimal("128.3645000")


async def seed_quest_fixture() -> dict[str, str]:
    """표준 단양군·청주시 region에 미션 타입별 테스트 퀘스트를 시드한다."""
    from sqlalchemy import select

    from app.core.database import AsyncSessionLocal
    from app.quests.models import Quest
    from app.regions.models import Region

    async with AsyncSessionLocal() as session:
        danyang = (
            await session.execute(select(Region).where(Region.slug == "danyang"))
        ).scalar_one()
        cheongju = (
            await session.execute(select(Region).where(Region.slug == "cheongju"))
        ).scalar_one()

        gps_quest = Quest(
            region_id=danyang.id,
            client_key="test-gps-quest",
            title="도담삼봉 인증샷",
            category="nature",
            mission_type="gps_photo",
            mission_meta={"judgement_prompt": "사진에 도담삼봉이 있는가?"},
            lat=DODAM_LAT,
            lng=DODAM_LNG,
            verify_radius=200,
        )
        quiz_quest = Quest(
            region_id=danyang.id,
            client_key="test-quiz-quest",
            title="온달동굴 OX 퀴즈",
            category="history",
            mission_type="quiz",
            mission_meta={"quiz": {"question": "온달동굴은 석회동굴이다?", "answer": "O"}},
        )
        photo_quest = Quest(
            region_id=danyang.id,
            client_key="test-photo-quest",
            title="단양 사진 인증",
            category="healing",
            mission_type="photo",
        )
        gps_only_quest = Quest(
            region_id=danyang.id,
            client_key="test-gps-only-quest",
            title="단양 위치 인증",
            category="activity",
            mission_type="gps",
            lat=DODAM_LAT,
            lng=DODAM_LNG,
            verify_radius=200,
        )
        food_quest = Quest(
            region_id=danyang.id,
            client_key="test-food-quest",
            title="마늘정식 먹기",
            category="food",
            mission_type="gps_photo",
            lat=Decimal("36.9800000"),
            lng=Decimal("128.3700000"),
        )
        other_region_quest = Quest(
            region_id=cheongju.id,
            client_key="test-other-region-quest",
            title="상당산성 둘레길",
            category="nature",
            mission_type="gps_photo",
            lat=Decimal("36.6360000"),
            lng=Decimal("127.5060000"),
        )
        session.add_all(
            [
                gps_quest,
                quiz_quest,
                photo_quest,
                gps_only_quest,
                food_quest,
                other_region_quest,
            ]
        )
        await session.commit()

        return {
            "region_id": str(danyang.id),
            "other_region_id": str(cheongju.id),
            "gps_quest_id": str(gps_quest.id),
            "quiz_quest_id": str(quiz_quest.id),
            "photo_quest_id": str(photo_quest.id),
            "gps_only_quest_id": str(gps_only_quest.id),
            "food_quest_id": str(food_quest.id),
            "other_region_quest_id": str(other_region_quest.id),
        }
