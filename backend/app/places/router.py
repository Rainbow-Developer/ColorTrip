"""places — API 라우터.

규약: docs/conventions/api-design.md (Envelope 응답, /api/v1 prefix는 main에서 부여)
공개 엔드포인트(GET /regions와 동일) — TourAPI 키는 서버만 들고 앱은 이 프록시만 호출한다.
"""

from collections.abc import AsyncGenerator

import httpx
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.core.response import Envelope, success
from app.integrations.tour_api.client import TourApiClient
from app.places import service
from app.places.schemas import FestivalRead, PlaceDetail, PlaceImage

router = APIRouter(prefix="/places", tags=["places"])

# 행사·축제도 TourAPI 프록시 책임이라 같은 모듈에 둔다(docs/specs/095-festival-info).
festivals_router = APIRouter(prefix="/festivals", tags=["festivals"])


# 프록시 응답이 화면 로딩을 막지 않도록 짧게 잡는다(plan.md 리스크 — 공공 API 지연).
_TIMEOUT_SECONDS = 5.0


async def get_tour_api_client() -> AsyncGenerator[TourApiClient]:
    """요청 단위 TourAPI 클라이언트(테스트에서 오버라이드)."""
    async with httpx.AsyncClient(timeout=_TIMEOUT_SECONDS) as http_client:
        yield TourApiClient(http_client=http_client)


@router.get("")
async def list_place_images(
    region_slug: str = Query(min_length=1),
    session: AsyncSession = Depends(get_session),
    client: TourApiClient = Depends(get_tour_api_client),
) -> Envelope[list[PlaceImage]]:
    data = await service.list_region_place_images(session, region_slug, client)
    return success(data)


@router.get("/{content_id}")
async def get_place(
    content_id: str,
    content_type_id: str = Query(min_length=1),
    client: TourApiClient = Depends(get_tour_api_client),
) -> Envelope[PlaceDetail]:
    data = await service.get_place_detail(content_id, content_type_id, client)
    return success(data)


@festivals_router.get("")
async def list_festivals(
    region_slug: str = Query(min_length=1),
    session: AsyncSession = Depends(get_session),
    client: TourApiClient = Depends(get_tour_api_client),
) -> Envelope[list[FestivalRead]]:
    data = await service.list_region_festivals(session, region_slug, client)
    return success(data)
