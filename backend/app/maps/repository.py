"""maps — 데이터 접근 계층 (SQLAlchemy 2.0 async)."""

from collections.abc import Sequence
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.enums import JourneyStatus
from app.journeys.models import Journey
from app.progress.models import MapProgress
from app.regions.models import Region


async def list_regions_with_progress(
    session: AsyncSession, user_id: UUID
) -> Sequence[tuple[Region, MapProgress | None]]:
    stmt = (
        select(Region, MapProgress)
        .outerjoin(
            MapProgress,
            (MapProgress.region_id == Region.id)
            & (MapProgress.user_id == user_id)
            & MapProgress.deleted_at.is_(None),
        )
        .where(Region.deleted_at.is_(None))
        .order_by(Region.name.asc())
    )
    result = await session.execute(stmt)
    # Row를 (Region, MapProgress|None) 튜플로 풀어 반환 타입과 맞춘다(outer join이라 None 가능).
    return [(row[0], row[1]) for row in result.all()]


async def count_completed_journeys_by_region(
    session: AsyncSession, user_id: UUID
) -> dict[UUID, int]:
    """사용자가 완료한 여정 수를 region_id별로 집계한다 (soft delete 제외).

    지도 채색 기준(완료 여행 수) — docs/specs/035-journey-map-coloring/plan.md
    """
    stmt = (
        select(Journey.region_id, func.count(Journey.id))
        .where(
            Journey.user_id == user_id,
            Journey.status == JourneyStatus.COMPLETED.value,
            Journey.deleted_at.is_(None),
        )
        .group_by(Journey.region_id)
    )
    rows = (await session.execute(stmt)).all()
    return {region_id: count for region_id, count in rows}
