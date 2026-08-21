"""행사·축제 프록시 API 테스트 (KAN-103, docs/specs/095-festival-info)."""

from datetime import date, timedelta
from typing import Any

import httpx
from httpx import AsyncClient

from app.main import app
from app.places.router import get_tour_api_client


def _yyyymmdd(d: date) -> str:
    return d.strftime("%Y%m%d")


class _FakeTourApiClient:
    def __init__(self, items: list[dict[str, Any]] | Exception) -> None:
        self._items = items

    async def fetch_festivals(
        self, ldong_regn_cd: str, event_start_date: str, rows: int = 100
    ) -> list[dict[str, Any]]:
        assert ldong_regn_cd == "43", "충북 법정동 시도코드로 조회해야 한다"
        if isinstance(self._items, Exception):
            raise self._items
        return self._items


def _override(fake: _FakeTourApiClient) -> None:
    app.dependency_overrides[get_tour_api_client] = lambda: fake


async def test_festivals_filters_by_region_and_window(client: AsyncClient) -> None:
    """addr1 지역명으로 거르고, 60일 밖 개막 예정은 제외하며 개막일순으로 정렬한다."""
    today = date.today()
    _override(
        _FakeTourApiClient(
            [
                {
                    "contentid": "1",
                    "title": "단양 온달문화축제",
                    "addr1": "충청북도 단양군 영춘면",
                    "eventstartdate": _yyyymmdd(today + timedelta(days=10)),
                    "eventenddate": _yyyymmdd(today + timedelta(days=13)),
                    "firstimage": "http://tong.visitkorea.or.kr/festival.jpg",
                    "mapx": "128.4801",
                    "mapy": "37.0578",
                },
                {
                    "contentid": "2",
                    "title": "단양 진행 중 축제",
                    "addr1": "충청북도 단양군 단양읍",
                    "eventstartdate": _yyyymmdd(today - timedelta(days=2)),
                    "eventenddate": _yyyymmdd(today + timedelta(days=2)),
                    "firstimage": "",
                },
                {
                    "contentid": "3",
                    "title": "다른 지역 축제",
                    "addr1": "충청북도 괴산군 괴산읍",
                    "eventstartdate": _yyyymmdd(today),
                    "eventenddate": _yyyymmdd(today),
                },
                {
                    "contentid": "4",
                    "title": "단양 먼 미래 축제",
                    "addr1": "충청북도 단양군",
                    "eventstartdate": _yyyymmdd(today + timedelta(days=90)),
                    "eventenddate": _yyyymmdd(today + timedelta(days=95)),
                },
            ]
        )
    )

    response = await client.get("/api/v1/festivals", params={"region_slug": "danyang"})

    assert response.status_code == 200
    data = response.json()["data"]
    assert [f["id"] for f in data] == ["2", "1"]  # 개막일 오름차순, 타지역·60일 밖 제외
    assert data[1]["poster_url"] == "https://tong.visitkorea.or.kr/festival.jpg"  # https 변환
    assert data[0]["poster_url"] is None
    assert data[1]["lat"] == 37.0578 and data[1]["lng"] == 128.4801


async def test_festivals_unknown_region_returns_404(client: AsyncClient) -> None:
    _override(_FakeTourApiClient([]))

    response = await client.get("/api/v1/festivals", params={"region_slug": "nope"})

    assert response.status_code == 404


async def test_festivals_tour_api_failure_returns_empty(client: AsyncClient) -> None:
    """TourAPI 실패 시 200 + 빈 목록 — 앱은 섹션을 숨긴다."""
    _override(_FakeTourApiClient(httpx.ConnectTimeout("timeout")))

    response = await client.get("/api/v1/festivals", params={"region_slug": "danyang"})

    assert response.status_code == 200
    assert response.json()["data"] == []
