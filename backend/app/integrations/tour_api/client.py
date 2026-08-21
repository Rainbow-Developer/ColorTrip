"""한국관광공사 TourAPI(KorService2) 비동기 클라이언트.

규약: docs/conventions/external-apis.md (TourAPI, 키는 환경변수+Secret Manager)

키가 없으면(settings.tour_api_key == "") 실제 HTTP 호출 없이 빈 결과를 반환한다.
응답 파싱은 data["response"]["body"]["items"]["item"] 경로가 없으면 빈/None을 반환한다.
"""

import logging
from typing import Any, Self

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)

# KorService2 공통 쿼리 파라미터
_COMMON_PARAMS: dict[str, str] = {
    "MobileOS": "ETC",
    "MobileApp": "ColorTrip",
    "_type": "json",
}


def _extract_items(data: dict[str, Any]) -> list[dict[str, Any]]:
    """data["response"]["body"]["items"]["item"]를 방어적으로 추출한다.

    item이 단일 dict면 리스트로 감싸고, 경로가 없거나 비면 빈 리스트를 반환한다.
    """
    # 각 단계가 dict가 아니면(에러 응답이 문자열로 오는 경우 등) 빈 리스트 반환
    node: Any = data
    for key in ("response", "body", "items"):
        if not isinstance(node, dict):
            return []
        node = node.get(key, {})
    if not isinstance(node, dict):
        return []
    item = node.get("item")
    if item is None:
        return []
    if isinstance(item, dict):
        return [item]
    if isinstance(item, list):
        return [entry for entry in item if isinstance(entry, dict)]
    return []


class TourApiClient:
    """TourAPI(KorService2) 호출용 비동기 클라이언트.

    `async with TourApiClient() as client:` 형태로 사용한다.
    내부 httpx.AsyncClient를 생성하거나 주입받는다.
    """

    def __init__(self, http_client: httpx.AsyncClient | None = None) -> None:
        self._base_url = settings.tour_api_base_url
        self._api_key = settings.tour_api_key
        self._owns_client = http_client is None
        self._client = http_client or httpx.AsyncClient(timeout=10.0)

    async def __aenter__(self) -> Self:
        return self

    async def __aexit__(self, *exc: object) -> None:
        await self.aclose()

    async def aclose(self) -> None:
        """내부에서 생성한 httpx 클라이언트만 닫는다(주입받은 것은 호출자 책임)."""
        if self._owns_client:
            await self._client.aclose()

    async def _get_items(self, endpoint: str, params: dict[str, Any]) -> list[dict[str, Any]]:
        """공통 파라미터를 붙여 호출하고 items.item 리스트를 반환한다.

        키가 없으면 HTTP 호출 없이 빈 리스트를 반환한다.
        """
        if not self._api_key:
            logger.warning("TOUR_API_KEY가 비어 있어 %s 호출을 건너뜁니다.", endpoint)
            return []

        query: dict[str, Any] = {
            "serviceKey": self._api_key,
            **_COMMON_PARAMS,
            **{key: value for key, value in params.items() if value is not None},
        }
        response = await self._client.get(f"{self._base_url}/{endpoint}", params=query)
        response.raise_for_status()
        try:
            data = response.json()
        except ValueError:  # TourAPI는 오류를 200 + 비JSON 본문으로 주기도 한다(external-apis.md)
            logger.warning("TourAPI %s 응답이 JSON이 아닙니다 — 빈 결과로 처리합니다.", endpoint)
            return []
        return _extract_items(data)

    async def fetch_area_based(
        self,
        area_code: str,
        sigungu_code: str | None = None,
        content_type_id: str | None = None,
        page: int = 1,
        rows: int = 100,
    ) -> list[dict[str, Any]]:
        """areaBasedList2 — 지역 기반 관광정보 목록(items.item)을 반환한다."""
        params: dict[str, Any] = {
            "areaCode": area_code,
            "sigunguCode": sigungu_code,
            "contentTypeId": content_type_id,
            "pageNo": page,
            "numOfRows": rows,
        }
        return await self._get_items("areaBasedList2", params)

    async def fetch_detail_intro(
        self, content_id: str, content_type_id: str
    ) -> dict[str, Any] | None:
        """detailIntro2 — 소개 정보의 첫 item을 반환한다(없으면 None)."""
        params: dict[str, Any] = {
            "contentId": content_id,
            "contentTypeId": content_type_id,
        }
        items = await self._get_items("detailIntro2", params)
        return items[0] if items else None

    async def fetch_category_codes(
        self,
        content_type_id: str | None = None,
        cat1: str | None = None,
        cat2: str | None = None,
    ) -> list[dict[str, Any]]:
        """categoryCode2 — 서비스 분류코드 목록(items.item)을 반환한다."""
        params: dict[str, Any] = {
            "contentTypeId": content_type_id,
            "cat1": cat1,
            "cat2": cat2,
        }
        return await self._get_items("categoryCode2", params)

    async def fetch_detail_common(self, content_id: str) -> dict[str, Any] | None:
        """detailCommon2 — 공통 상세(소개문·대표 이미지)의 첫 item을 반환한다(없으면 None)."""
        items = await self._get_items("detailCommon2", {"contentId": content_id})
        return items[0] if items else None

    async def fetch_festivals(
        self, ldong_regn_cd: str, event_start_date: str, rows: int = 100
    ) -> list[dict[str, Any]]:
        """searchFestival2 — 행사·축제 목록(items.item)을 반환한다.

        areaCode 파라미터는 0건을 반환하므로(법정동 코드 전환 영향) 법정동
        시도코드(lDongRegnCd)를 쓴다. eventStartDate는 종료일 기준 필터라
        진행 중 행사도 포함된다(2026-08-21 실호출 검증 — external-apis.md).
        """
        params: dict[str, Any] = {
            "lDongRegnCd": ldong_regn_cd,
            "eventStartDate": event_start_date,
            "numOfRows": rows,
            "pageNo": 1,
        }
        return await self._get_items("searchFestival2", params)
