"""regions — 데이터 접근 계층 (SQLAlchemy 2.0 async)."""

from collections.abc import Sequence
from uuid import UUID

from sqlalchemy import and_, case, exists, func, literal, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.enums import ProgressStatus
from app.journeys.models import Journey
from app.quests.models import Quest, QuestProgress
from app.regions.models import Region


async def list_regions(session: AsyncSession) -> Sequence[Region]:
    """삭제되지 않은 지역을 name 오름차순으로 조회."""
    stmt = select(Region).where(Region.deleted_at.is_(None)).order_by(Region.name.asc())
    result = await session.execute(stmt)
    return result.scalars().all()


async def get_region_by_slug(session: AsyncSession, slug: str) -> Region | None:
    """slug로 지역 1건을 조회한다(삭제된 지역 제외, 없으면 None)."""
    stmt = select(Region).where(Region.slug == slug, Region.deleted_at.is_(None))
    result = await session.execute(stmt)
    return result.scalar_one_or_none()


async def list_unvisited_recommendations(
    session: AsyncSession,
    user_id: UUID,
    preferred_category: str | None,
    page: int,
    size: int,
) -> tuple[list[tuple[Region, int, int]], int]:
    """여정 미생성 지역의 안정 키 보유·미완료 퀘스트 수를 집계한다."""
    completed = exists().where(
        QuestProgress.quest_id == Quest.id,
        QuestProgress.user_id == user_id,
        QuestProgress.status == ProgressStatus.COMPLETED.value,
        QuestProgress.deleted_at.is_(None),
    )
    has_journey = exists().where(
        Journey.user_id == user_id,
        Journey.region_id == Region.id,
        Journey.deleted_at.is_(None),
    )
    eligible_quest = and_(
        Quest.region_id == Region.id,
        Quest.deleted_at.is_(None),
        Quest.client_key.is_not(None),
        ~completed,
    )
    available_count = func.count(Quest.id)
    matching_count = (
        func.coalesce(
            func.sum(case((Quest.category == preferred_category, 1), else_=0)),
            0,
        )
        if preferred_category is not None
        else literal(0)
    )
    stmt = (
        select(
            Region,
            matching_count.label("matching_quest_count"),
            available_count.label("available_quest_count"),
        )
        .outerjoin(Quest, eligible_quest)
        .where(Region.deleted_at.is_(None), ~has_journey)
        .group_by(Region.id)
        .having(available_count > 0)
    )
    if preferred_category is not None:
        stmt = stmt.order_by(matching_count.desc())
    stmt = stmt.order_by(available_count.desc(), Region.name.asc())
    rows = (await session.execute(stmt)).all()
    total = len(rows)
    start = (page - 1) * size
    page_rows = rows[start : start + size]
    return [
        (region, int(matching), int(available)) for region, matching, available in page_rows
    ], total
