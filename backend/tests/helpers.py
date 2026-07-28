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
            "email": data["user"]["email"] or "test@example.com",
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

        async with AsyncSessionLocal() as session:
            user = await session.get(User, UUID(data["user"]["id"]))
            assert user is not None
            user.dna = "nature"
            await session.commit()
    return headers


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
