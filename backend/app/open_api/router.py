from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.core.response import Envelope, success
from app.open_api import service
from app.open_api.dependencies import ActiveOpenApiKey
from app.open_api.schemas import RegionStatsResponse

router = APIRouter(tags=["open_api"])


@router.get(
    "/open/regions/{region_slug}/stats",
    response_model=Envelope[RegionStatsResponse],
)
async def get_region_stats(
    region_slug: str,
    _key: ActiveOpenApiKey,
    months: int = Query(default=6, ge=1, le=36),
    session: AsyncSession = Depends(get_session),
) -> Envelope[RegionStatsResponse]:
    """지자체 등 외부 기관이 serviceKey로 조회하는 지역 관광 통계.

    지역 목록은 기존 공개 API `GET /api/v1/regions`를 참고한다(별도 엔드포인트 없음).
    """
    stats = await service.get_region_stats(session, region_slug, months)
    return success(stats)
