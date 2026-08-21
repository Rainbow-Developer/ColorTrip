"""places — TourAPI 장소 정보 실시간 프록시.

규약: docs/specs/090-realtime-tour-place-info/plan.md
- 지역 썸네일: areaBasedList2(유형 12·14·28·39) → contentid별 대표 이미지
- 장소 상세: detailCommon2(이미지·소개문) + detailIntro2(운영정보)
- TourAPI 오류·타임아웃 시 해당 필드를 비워 반환한다(앱이 placeholder 표시).
"""

import asyncio
import logging

import httpx
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AppException, ErrorCode
from app.integrations.tour_api.client import TourApiClient
from app.places.schemas import OperationInfo, PlaceDetail, PlaceImage
from app.regions.repository import get_region_by_slug

logger = logging.getLogger(__name__)


def _https(url: str) -> str:
    """http URL을 https로 바꾼다 — release 빌드는 평문을 차단한다(TourAPI CDN은 https 지원)."""
    return url.replace("http://", "https://", 1) if url.startswith("http://") else url


# 서비스 지역이 충북뿐이므로 areaCode를 고정한다(regions.area_code는 sigunguCode).
_CHUNGBUK_AREA_CODE = "33"

# 퀘스트 후보 수집과 동일한 유형(관광지·문화시설·레포츠·음식점) — external-apis.md
_CONTENT_TYPE_IDS = ("12", "14", "28", "39")

# detailIntro2의 운영정보 필드명은 contentTypeId마다 다르다 → (usetime, restdate)로 정규화
_OPERATION_FIELDS: dict[str, tuple[str, str]] = {
    "12": ("usetime", "restdate"),
    "14": ("usetimeculture", "restdateculture"),
    "28": ("usetimeleports", "restdateleports"),
    "39": ("opentimefood", "restdatefood"),
}


async def list_region_place_images(
    session: AsyncSession, region_slug: str, client: TourApiClient
) -> list[PlaceImage]:
    """지역의 관광지 대표 이미지 목록을 실시간 조회한다.

    유형별 호출 중 일부가 실패해도 성공한 유형의 결과는 반환한다.
    """
    region = await get_region_by_slug(session, region_slug)
    if region is None or not region.area_code:
        raise AppException(ErrorCode.NOT_FOUND_ERROR, f"존재하지 않는 지역: {region_slug}")

    results = await asyncio.gather(
        *(
            client.fetch_area_based(
                _CHUNGBUK_AREA_CODE, sigungu_code=region.area_code, content_type_id=ctid
            )
            for ctid in _CONTENT_TYPE_IDS
        ),
        return_exceptions=True,
    )

    images: dict[str, str] = {}
    for ctid, result in zip(_CONTENT_TYPE_IDS, results, strict=True):
        if isinstance(result, BaseException):
            if not isinstance(result, httpx.HTTPError):
                raise result  # TourAPI 통신 오류 외의 예외는 버그 — 삼키지 않는다
            logger.warning(
                "TourAPI areaBasedList2 실패 (slug=%s, contentTypeId=%s): %s",
                region_slug,
                ctid,
                result,
            )
            continue
        for item in result:
            content_id = str(item.get("contentid") or "")
            image_url = str(item.get("firstimage") or "")
            if content_id and image_url:
                images.setdefault(content_id, _https(image_url))

    return [PlaceImage(content_id=cid, image_url=url) for cid, url in images.items()]


async def get_place_detail(
    content_id: str, content_type_id: str, client: TourApiClient
) -> PlaceDetail:
    """장소 상세(이미지·소개문·운영정보)를 실시간 조회한다. 실패한 항목은 null."""
    common, intro = await asyncio.gather(
        client.fetch_detail_common(content_id),
        client.fetch_detail_intro(content_id, content_type_id),
        return_exceptions=True,
    )

    detail = PlaceDetail(content_id=content_id)

    if isinstance(common, BaseException):
        if not isinstance(common, httpx.HTTPError):
            raise common
        logger.warning("TourAPI detailCommon2 실패 (contentId=%s): %s", content_id, common)
    elif common is not None:
        first_image = str(common.get("firstimage") or "")
        detail.image_url = _https(first_image) if first_image else None
        detail.overview = str(common.get("overview") or "").strip() or None

    if isinstance(intro, BaseException):
        if not isinstance(intro, httpx.HTTPError):
            raise intro
        logger.warning("TourAPI detailIntro2 실패 (contentId=%s): %s", content_id, intro)
    elif intro is not None:
        fields = _OPERATION_FIELDS.get(content_type_id)
        if fields is not None:
            usetime = str(intro.get(fields[0]) or "").strip() or None
            restdate = str(intro.get(fields[1]) or "").strip() or None
            if usetime or restdate:
                detail.operation_info = OperationInfo(usetime=usetime, restdate=restdate)

    return detail
