"""places 프록시 API 테스트 — TourAPI 대역으로 실시간 조회·실패 동작을 검증한다(KAN-102)."""

from typing import Any

import httpx
from httpx import AsyncClient

from app.main import app
from app.places.router import get_tour_api_client


class _FakeTourApiClient:
    """지정한 응답/예외만 돌려주는 TourAPI 대역."""

    def __init__(
        self,
        area_items: dict[str, list[dict[str, Any]] | Exception] | None = None,
        common: dict[str, Any] | Exception | None = None,
        intro: dict[str, Any] | Exception | None = None,
    ) -> None:
        self._area_items = area_items or {}
        self._common = common
        self._intro = intro

    async def fetch_area_based(
        self,
        area_code: str,
        sigungu_code: str | None = None,
        content_type_id: str | None = None,
        page: int = 1,
        rows: int = 100,
    ) -> list[dict[str, Any]]:
        result = self._area_items.get(content_type_id or "", [])
        if isinstance(result, Exception):
            raise result
        return result

    async def fetch_detail_common(self, content_id: str) -> dict[str, Any] | None:
        if isinstance(self._common, Exception):
            raise self._common
        return self._common

    async def fetch_detail_intro(
        self, content_id: str, content_type_id: str
    ) -> dict[str, Any] | None:
        if isinstance(self._intro, Exception):
            raise self._intro
        return self._intro


def _override_client(fake: _FakeTourApiClient) -> None:
    app.dependency_overrides[get_tour_api_client] = lambda: fake


async def test_place_images_returns_content_id_image_map(client: AsyncClient) -> None:
    _override_client(
        _FakeTourApiClient(
            area_items={
                "12": [
                    {"contentid": "100", "firstimage": "https://tong.example/100.jpg"},
                    {"contentid": "101", "firstimage": ""},  # 이미지 없는 항목은 제외
                ],
                "39": [{"contentid": "200", "firstimage": "https://tong.example/200.jpg"}],
            }
        )
    )

    response = await client.get("/api/v1/places", params={"region_slug": "danyang"})

    assert response.status_code == 200
    items = {item["content_id"]: item["image_url"] for item in response.json()["data"]}
    assert items == {
        "100": "https://tong.example/100.jpg",
        "200": "https://tong.example/200.jpg",
    }


async def test_place_images_partial_failure_returns_successful_types(
    client: AsyncClient,
) -> None:
    """유형별 호출 중 일부가 실패해도 성공한 유형의 이미지는 반환한다."""
    _override_client(
        _FakeTourApiClient(
            area_items={
                "12": httpx.ConnectTimeout("timeout"),
                "14": [{"contentid": "300", "firstimage": "https://tong.example/300.jpg"}],
            }
        )
    )

    response = await client.get("/api/v1/places", params={"region_slug": "danyang"})

    assert response.status_code == 200
    assert response.json()["data"] == [
        {"content_id": "300", "image_url": "https://tong.example/300.jpg"}
    ]


async def test_place_images_unknown_region_returns_404(client: AsyncClient) -> None:
    _override_client(_FakeTourApiClient())

    response = await client.get("/api/v1/places", params={"region_slug": "no-such-region"})

    assert response.status_code == 404
    assert response.json()["code"] == "NOT_FOUND_ERROR"


async def test_place_detail_merges_common_and_intro(client: AsyncClient) -> None:
    _override_client(
        _FakeTourApiClient(
            common={
                "firstimage": "https://tong.example/detail.jpg",
                "overview": "단양팔경 중 하나인 중선암은 ...",
            },
            intro={"usetime": "09:00~18:00", "restdate": "연중무휴"},
        )
    )

    response = await client.get("/api/v1/places/100", params={"content_type_id": "12"})

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["content_id"] == "100"
    assert data["image_url"] == "https://tong.example/detail.jpg"
    assert data["overview"].startswith("단양팔경")
    assert data["operation_info"] == {"usetime": "09:00~18:00", "restdate": "연중무휴"}


async def test_place_detail_normalizes_food_operation_fields(client: AsyncClient) -> None:
    """detailIntro2 필드명은 유형별로 다르다 — 음식점(39)은 opentimefood/restdatefood."""
    _override_client(
        _FakeTourApiClient(
            common={"firstimage": "", "overview": ""},
            intro={"opentimefood": "11:00~21:00", "restdatefood": "매주 월요일"},
        )
    )

    response = await client.get("/api/v1/places/200", params={"content_type_id": "39"})

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["image_url"] is None
    assert data["overview"] is None
    assert data["operation_info"] == {"usetime": "11:00~21:00", "restdate": "매주 월요일"}


async def test_place_detail_tour_api_failure_returns_null_fields(client: AsyncClient) -> None:
    """TourAPI 실패 시 필드를 null로 응답한다 — 앱은 placeholder를 표시한다."""
    _override_client(
        _FakeTourApiClient(
            common=httpx.ConnectTimeout("timeout"),
            intro=httpx.HTTPStatusError(
                "500",
                request=httpx.Request("GET", "https://apis.example"),
                response=httpx.Response(500),
            ),
        )
    )

    response = await client.get("/api/v1/places/100", params={"content_type_id": "12"})

    assert response.status_code == 200
    data = response.json()["data"]
    assert data == {
        "content_id": "100",
        "image_url": None,
        "overview": None,
        "operation_info": None,
    }


async def test_migration_backfills_quest_content_ids(client: AsyncClient) -> None:
    """KAN-102 마이그레이션이 client_key 기준으로 quests.content_id를 채운다."""
    from sqlalchemy import select

    from app.core.database import AsyncSessionLocal
    from app.quests.models import Quest

    async with AsyncSessionLocal() as session:
        quest = (await session.execute(select(Quest).where(Quest.client_key == "dy6"))).scalar_one()

    assert quest.content_id == "1626649"
    assert quest.content_type_id == "12"


async def test_tour_client_non_json_response_returns_empty(client: AsyncClient) -> None:
    """TourAPI가 오류를 200 + 비JSON 본문으로 줄 때 500 없이 빈 결과로 처리한다."""
    import httpx as _httpx

    from app.core.config import settings as _settings
    from app.integrations.tour_api.client import TourApiClient

    def _handler(request: _httpx.Request) -> _httpx.Response:
        return _httpx.Response(200, text="SERVICE ERROR")  # 비표준 텍스트 오류

    transport = _httpx.MockTransport(_handler)
    original_key = _settings.tour_api_key
    _settings.tour_api_key = "test-key"
    try:
        async with _httpx.AsyncClient(transport=transport) as http_client:
            tour = TourApiClient(http_client=http_client)
            assert await tour.fetch_area_based("33") == []
            assert await tour.fetch_detail_common("100") is None
    finally:
        _settings.tour_api_key = original_key
