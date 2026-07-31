"""홈 DNA 지역 추천 API 테스트 (GET /api/v1/home/recommendation).

기능 스펙: docs/specs/040-home-region-recommendation/plan.md
"""

from decimal import Decimal
from uuid import UUID

from httpx import AsyncClient

from app.auth.models import User
from app.core.database import AsyncSessionLocal
from app.home import service as home_service
from app.quests.models import Quest
from app.regions.models import Region
from tests.helpers import auth_headers, complete_auth_headers, login

GUGYEONG_THUMB = "https://img.example.com/gugyeong.jpg"
CHEONGNAMDAE_THUMB = "https://img.example.com/cheongnamdae.jpg"

# GPS 인증용 좌표 (퀘스트 좌표와 동일 지점으로 인증해 여정을 완료시킨다)
GARLIC_LAT, GARLIC_LNG = Decimal("36.9800000"), Decimal("128.3700000")
FORTRESS_LAT, FORTRESS_LNG = Decimal("36.6360000"), Decimal("127.5060000")


async def _seed_home_fixture() -> dict[str, str]:
    """추천 시나리오용 지역·퀘스트를 시드한다.

    - 단양군: food 2(썸네일 1) + nature 1 → food DNA의 최다 지역
    - 청주시: nature 3(썸네일 1) + food 1 + history 1 → nature DNA의 최다 지역, 전체 5개
    """
    async with AsyncSessionLocal() as session:
        danyang = Region(name="단양군", area_code="21")
        cheongju = Region(name="청주시", area_code="1")
        session.add_all([danyang, cheongju])
        await session.flush()

        gugyeong = Quest(
            region_id=danyang.id,
            title="구경시장 먹거리 투어",
            category="food",
            thumbnail_url=GUGYEONG_THUMB,
        )
        garlic = Quest(
            region_id=danyang.id,
            title="마늘정식 먹기",
            category="food",
            lat=GARLIC_LAT,
            lng=GARLIC_LNG,
        )
        dodam = Quest(
            region_id=danyang.id,
            title="도담삼봉 인증샷",
            category="nature",
            thumbnail_url="https://img.example.com/dodam.jpg",
        )
        fortress = Quest(
            region_id=cheongju.id,
            title="상당산성 둘레길",
            category="nature",
            lat=FORTRESS_LAT,
            lng=FORTRESS_LNG,
        )
        cheongnamdae = Quest(
            region_id=cheongju.id,
            title="청남대 산책",
            category="nature",
            thumbnail_url=CHEONGNAMDAE_THUMB,
        )
        musim = Quest(region_id=cheongju.id, title="무심천 벚꽃길", category="nature")
        pork = Quest(region_id=cheongju.id, title="삼겹살 거리 인증", category="food")
        ginkgo = Quest(region_id=cheongju.id, title="중앙공원 압각수", category="history")
        session.add_all([gugyeong, garlic, dodam, fortress, cheongnamdae, musim, pork, ginkgo])
        await session.commit()

        return {
            "danyang_id": str(danyang.id),
            "cheongju_id": str(cheongju.id),
            "gugyeong_id": str(gugyeong.id),
            "garlic_id": str(garlic.id),
            "dodam_id": str(dodam.id),
            "fortress_id": str(fortress.id),
        }


async def _set_user_dna(user_id: UUID, dna: str) -> None:
    """설문(trip_dna) 흐름 없이 대표 DNA를 직접 세팅한다."""
    async with AsyncSessionLocal() as session:
        user = await session.get(User, user_id)
        assert user is not None
        user.dna = dna
        await session.commit()


async def _login_with_dna(client: AsyncClient, dna: str) -> dict[str, str]:
    """온보딩까지 마친 헤더를 만들고 대표 DNA를 원하는 값으로 덮어쓴다.

    도메인 API는 온보딩 완료 전 403(ONBOARDING_REQUIRED)이므로 온보딩을 거쳐야 한다
    (KAN-53). `complete_auth_headers`가 dna를 nature로 세팅하니 그 뒤에 덮어쓴다.
    """
    data = await login(client)
    headers = await complete_auth_headers(client, data)
    await _set_user_dna(UUID(data["user"]["id"]), dna)
    return headers


async def _complete_journey(
    client: AsyncClient,
    headers: dict[str, str],
    region_id: str,
    quest_id: str,
    lat: Decimal,
    lng: Decimal,
) -> None:
    """여정 생성 → 퀘스트 GPS 인증으로 여정을 completed로 전이시킨다."""
    created = await client.post(
        "/api/v1/journeys",
        json={"region_id": region_id, "quest_ids": [quest_id]},
        headers=headers,
    )
    assert created.status_code == 201
    verify = await client.post(
        f"/api/v1/quests/{quest_id}/verify",
        json={"lat": str(lat), "lng": str(lng), "photo_url": "/uploads/x.jpg"},
        headers=headers,
    )
    assert verify.json()["data"]["verified"] is True


async def _get_recommendation(client: AsyncClient, headers: dict[str, str]) -> dict:
    response = await client.get("/api/v1/home/recommendation", headers=headers)
    assert response.status_code == 200
    return response.json()["data"]


async def test_recommendation_uses_user_dna(client: AsyncClient) -> None:
    """DNA가 있는 유저는 그 카테고리 퀘스트가 가장 많은 지역을 추천받는다."""
    seed = await _seed_home_fixture()
    headers = await _login_with_dna(client, "food")

    data = await _get_recommendation(client, headers)

    assert data["dna_category"] == "food"
    assert data["region"]["id"] == seed["danyang_id"]
    assert data["region"]["name"] == "단양군"
    # 대표 이미지 = 정렬(=요약)순 첫 썸네일 보유 퀘스트의 썸네일
    assert data["region"]["image_url"] == GUGYEONG_THUMB

    # 요약은 DNA 일치 우선 → 썸네일 보유 우선 (food+썸네일 → food → nature)
    assert [q["id"] for q in data["quests"]] == [
        seed["gugyeong_id"],
        seed["garlic_id"],
        seed["dodam_id"],
    ]
    first = data["quests"][0]
    assert first["title"] == "구경시장 먹거리 투어"
    assert first["category"] == "food"
    assert first["mission_type"] == "gps_photo"
    assert first["thumbnail_url"] == GUGYEONG_THUMB


async def test_recommendation_defaults_to_nature_without_dna(client: AsyncClient) -> None:
    """DNA 미판정 유저는 기본 카테고리(nature) 기준으로 추천받는다.

    DNA가 없는 유저는 온보딩 게이트(`app/auth/dependencies.py`, KAN-53)에 막혀 HTTP로
    도달할 수 없으므로 서비스 계층에서 직접 검증한다.
    """
    seed = await _seed_home_fixture()
    data = await login(client)
    user_id = UUID(data["user"]["id"])

    async with AsyncSessionLocal() as session:
        result = await home_service.get_home_recommendation(session, user_id=user_id)

    assert result.dna_category == "nature"
    assert str(result.region.id) == seed["cheongju_id"]
    assert result.region.image_url == CHEONGNAMDAE_THUMB

    # 지역 퀘스트가 5개여도 요약은 최대 3개, 전부 DNA 일치(nature)로 채워진다.
    assert len(result.quests) == 3
    assert all(q.category == "nature" for q in result.quests)
    assert result.quests[0].title == "청남대 산책"  # 썸네일 보유 우선


async def test_recommendation_deprioritizes_completed_regions(client: AsyncClient) -> None:
    """완료 여정이 있는 지역은 후순위로 밀리고, 전부 완료면 전체 최다로 돌아온다."""
    seed = await _seed_home_fixture()
    headers = await _login_with_dna(client, "food")

    # 단양군 여정을 완료하면 → 완료 여정 없는 청주시가 추천된다.
    await _complete_journey(
        client, headers, seed["danyang_id"], seed["garlic_id"], GARLIC_LAT, GARLIC_LNG
    )
    data = await _get_recommendation(client, headers)
    assert data["region"]["id"] == seed["cheongju_id"]
    assert data["dna_category"] == "food"

    # 청주시 여정까지 완료하면(모든 지역 완료) → 전체 중 food 최다인 단양군으로 복귀.
    await _complete_journey(
        client, headers, seed["cheongju_id"], seed["fortress_id"], FORTRESS_LAT, FORTRESS_LNG
    )
    data = await _get_recommendation(client, headers)
    assert data["region"]["id"] == seed["danyang_id"]


async def test_recommendation_without_quests_returns_404(client: AsyncClient) -> None:
    """퀘스트가 하나도 없으면 404를 반환한다 (FE는 정적 데이터로 폴백)."""
    headers = await auth_headers(client)
    response = await client.get("/api/v1/home/recommendation", headers=headers)
    assert response.status_code == 404
    assert response.json()["code"] == "NOT_FOUND_ERROR"


async def test_recommendation_requires_auth(client: AsyncClient) -> None:
    """인증 없이 호출하면 401을 반환해야 한다."""
    response = await client.get("/api/v1/home/recommendation")
    assert response.status_code == 401
