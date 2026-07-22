"""지도 진행 API 테스트 (GET /api/v1/users/me/map)."""

from datetime import datetime, timezone
from uuid import UUID

from httpx import AsyncClient

from tests.helpers import login


async def _seed_map_fixture(user_id: UUID) -> dict[str, str]:
    """지역 2개를 심고, 그 중 하나에만 map_progress 레코드를 생성한다."""
    from app.core.database import AsyncSessionLocal
    from app.progress.models import MapProgress
    from app.regions.models import Region

    async with AsyncSessionLocal() as session:
        danyang = Region(name="단양군", area_code="21")
        cheongju = Region(name="청주시", area_code="1")
        session.add_all([danyang, cheongju])
        await session.flush()

        progress = MapProgress(
            user_id=user_id,
            region_id=danyang.id,
            completed_count=3,
            first_colored_at=datetime(2026, 7, 1, 10, 0, 0, tzinfo=timezone.utc),
        )
        session.add(progress)
        await session.commit()

        return {
            "danyang_id": str(danyang.id),
            "cheongju_id": str(cheongju.id),
        }


async def test_my_map_returns_all_regions(client: AsyncClient) -> None:
    """방문한 지역·미방문 지역 모두 반환하고 completed_count가 정확해야 한다."""
    data = await login(client)
    user_id = UUID(data["user"]["id"])
    headers = {"Authorization": f"Bearer {data['access_token']}"}
    seed = await _seed_map_fixture(user_id)

    response = await client.get("/api/v1/users/me/map", headers=headers)
    assert response.status_code == 200
    items = response.json()["data"]

    assert len(items) == 2

    by_region = {item["region_id"]: item for item in items}
    assert by_region[seed["danyang_id"]]["region_name"] == "단양군"
    assert by_region[seed["danyang_id"]]["completed_count"] == 3
    assert by_region[seed["danyang_id"]]["first_colored_at"] is not None
    assert by_region[seed["cheongju_id"]]["region_name"] == "청주시"
    assert by_region[seed["cheongju_id"]]["completed_count"] == 0
    assert by_region[seed["cheongju_id"]]["first_colored_at"] is None


async def test_my_map_only_returns_my_progress(client: AsyncClient) -> None:
    """다른 유저의 map_progress는 내 응답에 포함되지 않는다."""
    owner_data = await login(client, "kakao-token-1")
    other_data = await login(client, "kakao-token-unknown")

    owner_id = UUID(owner_data["user"]["id"])
    owner_headers = {"Authorization": f"Bearer {owner_data['access_token']}"}
    other_headers = {"Authorization": f"Bearer {other_data['access_token']}"}

    seed = await _seed_map_fixture(owner_id)

    owner_items = {
        item["region_id"]: item
        for item in (await client.get("/api/v1/users/me/map", headers=owner_headers)).json()["data"]
    }
    assert owner_items[seed["danyang_id"]]["completed_count"] == 3

    other_items = {
        item["region_id"]: item
        for item in (await client.get("/api/v1/users/me/map", headers=other_headers)).json()["data"]
    }
    assert other_items[seed["danyang_id"]]["completed_count"] == 0


async def test_my_map_requires_auth(client: AsyncClient) -> None:
    """인증 없이 호출하면 401을 반환해야 한다."""
    response = await client.get("/api/v1/users/me/map")
    assert response.status_code == 401
