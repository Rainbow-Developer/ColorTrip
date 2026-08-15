from __future__ import annotations

import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.auth.models import User
from app.core.config import settings
from app.core.exceptions import AppException, ErrorCode
from app.progress.models import MapProgress
from app.regions.repository import list_regions
from app.shares import repository
from app.shares.schemas import (
    ColoredRegionItem,
    ShareCreateRequest,
    ShareCreateResponse,
    ShareReadResponse,
    ShareStyle,
    ShareSummaryResponse,
)

DNA_NAME_MAP = {
    "nature": "자연탐험형",
    "food": "미식탐방형",
    "history": "역사문화형",
    "activity": "액티비티형",
    "healing": "힐링휴식형",
}


async def get_user_share_summary_data(session: AsyncSession, user: User) -> ShareSummaryResponse:
    """사용자의 현재 여행 진행률, DNA, 색칠된 시·군 목록 요약 데이터를 생성합니다."""
    # 1. 마스터 시·군 목록 및 총 개수
    all_regions = await list_regions(session)
    total_region_count = len(all_regions)

    # 2. 유저의 색칠된 지도 진행률 조회 (completed_count > 0)
    stmt = (
        select(MapProgress)
        .options(joinedload(MapProgress.region))
        .where(
            MapProgress.user_id == user.id,
            MapProgress.completed_count > 0,
            MapProgress.deleted_at.is_(None),
        )
    )
    result = await session.execute(stmt)
    map_progresses = list(result.scalars().all())

    colored_regions = [
        ColoredRegionItem(
            id=mp.region.id,
            name=mp.region.name,
            area_code=mp.region.area_code,
        )
        for mp in map_progresses
        if mp.region is not None
    ]

    completed_region_count = len(colored_regions)
    progress_percentage = (
        int((completed_region_count / total_region_count) * 100) if total_region_count > 0 else 0
    )

    dna_type = user.dna
    dna_name = DNA_NAME_MAP.get(user.dna) if user.dna else None

    return ShareSummaryResponse(
        nickname=user.nickname,
        dna_type=dna_type,
        dna_name=dna_name,
        completed_region_count=completed_region_count,
        total_region_count=total_region_count,
        progress_percentage=progress_percentage,
        colored_regions=colored_regions,
    )


async def _representative_region_id(session: AsyncSession, user_id: uuid.UUID) -> uuid.UUID | None:
    """공유 생성 시점에 완료 퀘스트 수가 가장 많은 지역("대표 지역")을 찾는다.

    지자체 오픈 API의 지역별 공유 통계가 이 값을 근거로 집계한다
    (docs/specs/070-municipal-open-api).
    """
    stmt = (
        select(MapProgress.region_id)
        .where(
            MapProgress.user_id == user_id,
            MapProgress.completed_count > 0,
            MapProgress.deleted_at.is_(None),
        )
        .order_by(MapProgress.completed_count.desc())
        .limit(1)
    )
    result = await session.execute(stmt)
    return result.scalar_one_or_none()


async def create_share_card(
    session: AsyncSession, user: User, req: ShareCreateRequest
) -> ShareCreateResponse:
    """공유 숏코드 및 공유 카드 정보를 생성합니다."""
    repo = repository.ShareRepository()
    region_id = await _representative_region_id(session, user.id)
    share = await repo.create(
        session, user_id=user.id, share_style=req.share_style.value, region_id=region_id
    )
    await session.commit()

    share_url = f"{settings.share_base_url}/share/{share.share_code}"
    return ShareCreateResponse(
        share_code=share.share_code,
        share_url=share_url,
        share_style=share.share_style,
        created_at=share.created_at,
    )


async def get_public_share_card(session: AsyncSession, share_code: str) -> ShareReadResponse:
    """외부 사용자가 조회할 수 있는 공개 공유 카드 데이터를 가져옵니다."""
    repo = repository.ShareRepository()
    share = await repo.get_by_code(session, share_code)

    if share is None or share.user is None:
        raise AppException(ErrorCode.NOT_FOUND_ERROR, "존재하지 않는 공유 코드입니다.")

    summary = await get_user_share_summary_data(session, share.user)

    # 선택된 공유 스타일(MAP_AND_DNA, MAP, DNA)에 따라 응답 데이터 필터링
    dna_type = summary.dna_type
    dna_name = summary.dna_name
    colored_regions = summary.colored_regions

    if share.share_style == ShareStyle.MAP.value:
        dna_type = None
        dna_name = None
    elif share.share_style == ShareStyle.DNA.value:
        colored_regions = []

    return ShareReadResponse(
        share_code=share.share_code,
        share_style=share.share_style,
        owner_nickname=summary.nickname,
        dna_type=dna_type,
        dna_name=dna_name,
        completed_region_count=summary.completed_region_count,
        total_region_count=summary.total_region_count,
        progress_percentage=summary.progress_percentage,
        colored_regions=colored_regions,
    )
