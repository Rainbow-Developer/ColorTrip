"""maps — 데이터 접근 계층 (SQLAlchemy 2.0 async)."""

from collections.abc import Sequence
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.enums import ProgressStatus
from app.journeys.models import Journey, JourneyQuest
from app.progress.models import MapProgress
from app.quests.models import QuestProgress
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


async def count_colored_journeys_by_region(session: AsyncSession, user_id: UUID) -> dict[UUID, int]:
    """완료 퀘스트가 1개 이상인 여정 수를 region_id별로 집계한다 (soft delete 제외).

    지도 채색 기준 — docs/specs/055-journey-map-coloring/description.md.
    여정 `status`(완료/진행중)와는 무관하다: 퀘스트를 5개 담고 1개만 인증한 진행중 여정도
    1회로 센다. 한 여정에 완료 퀘스트가 여러 개여도 여정 단위로 1회다(DISTINCT).
    """
    stmt = (
        select(Journey.region_id, func.count(func.distinct(Journey.id)))
        .join(JourneyQuest, JourneyQuest.journey_id == Journey.id)
        .join(
            QuestProgress,
            (QuestProgress.quest_id == JourneyQuest.quest_id) & (QuestProgress.user_id == user_id),
        )
        .where(
            Journey.user_id == user_id,
            Journey.deleted_at.is_(None),
            JourneyQuest.deleted_at.is_(None),
            QuestProgress.deleted_at.is_(None),
            QuestProgress.status == ProgressStatus.COMPLETED.value,
        )
        .group_by(Journey.region_id)
    )
    rows = (await session.execute(stmt)).all()
    return {region_id: count for region_id, count in rows}
