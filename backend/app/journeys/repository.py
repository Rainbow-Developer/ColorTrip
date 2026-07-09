"""journeys — 데이터 접근 계층 (SQLAlchemy 2.0 async)."""

from collections.abc import Sequence
from uuid import UUID

from sqlalchemy import ColumnElement, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.enums import ProgressStatus
from app.journeys.models import Journey, JourneyQuest
from app.quests.models import Quest, QuestProgress


async def get_journey(session: AsyncSession, journey_id: UUID, user_id: UUID) -> Journey | None:
    """본인 소유의 여정 1건을 조회한다 (soft delete 제외)."""
    stmt = select(Journey).where(
        Journey.id == journey_id,
        Journey.user_id == user_id,
        Journey.deleted_at.is_(None),
    )
    return await session.scalar(stmt)


async def list_journeys(
    session: AsyncSession,
    user_id: UUID,
    status: str | None,
    page: int,
    size: int,
) -> tuple[Sequence[Journey], int]:
    """내 여정을 최신순으로 조회한다 (offset 페이지네이션)."""
    filters: list[ColumnElement[bool]] = [
        Journey.user_id == user_id,
        Journey.deleted_at.is_(None),
    ]
    if status is not None:
        filters.append(Journey.status == status)

    items_stmt = (
        select(Journey)
        .where(*filters)
        .order_by(Journey.created_at.desc())
        .offset((page - 1) * size)
        .limit(size)
    )
    items = (await session.execute(items_stmt)).scalars().all()

    count_stmt = select(func.count()).select_from(Journey).where(*filters)
    total = await session.scalar(count_stmt) or 0
    return items, total


async def list_journey_quests(session: AsyncSession, journey_id: UUID) -> Sequence[JourneyQuest]:
    """여정에 담긴 퀘스트를 정렬순으로 조회한다 (퀘스트 eager load)."""
    stmt = (
        select(JourneyQuest)
        .where(JourneyQuest.journey_id == journey_id, JourneyQuest.deleted_at.is_(None))
        .options(selectinload(JourneyQuest.quest))
        .order_by(JourneyQuest.sort_order)
    )
    return (await session.execute(stmt)).scalars().all()


async def get_journey_quest(
    session: AsyncSession, journey_id: UUID, quest_id: UUID
) -> JourneyQuest | None:
    """여정-퀘스트 1건을 soft delete 포함해 조회한다 (복원 판단용)."""
    stmt = select(JourneyQuest).where(
        JourneyQuest.journey_id == journey_id,
        JourneyQuest.quest_id == quest_id,
    )
    return await session.scalar(stmt)


async def max_sort_order(session: AsyncSession, journey_id: UUID) -> int:
    stmt = select(func.coalesce(func.max(JourneyQuest.sort_order), -1)).where(
        JourneyQuest.journey_id == journey_id, JourneyQuest.deleted_at.is_(None)
    )
    return await session.scalar(stmt) or -1


async def get_quests_by_ids(session: AsyncSession, quest_ids: list[UUID]) -> Sequence[Quest]:
    stmt = select(Quest).where(Quest.id.in_(quest_ids), Quest.deleted_at.is_(None))
    return (await session.execute(stmt)).scalars().all()


async def progress_status_map(
    session: AsyncSession, user_id: UUID, quest_ids: list[UUID]
) -> dict[UUID, str]:
    """사용자의 퀘스트별 진행 상태 맵을 반환한다."""
    if not quest_ids:
        return {}
    stmt = select(QuestProgress.quest_id, QuestProgress.status).where(
        QuestProgress.user_id == user_id,
        QuestProgress.quest_id.in_(quest_ids),
        QuestProgress.deleted_at.is_(None),
    )
    rows = (await session.execute(stmt)).all()
    return {quest_id: status for quest_id, status in rows}


async def list_journeys_containing_quest(
    session: AsyncSession, user_id: UUID, quest_id: UUID
) -> Sequence[Journey]:
    """해당 퀘스트를 담고 있는 내 여정 목록 (완료 전파용)."""
    stmt = (
        select(Journey)
        .join(JourneyQuest, JourneyQuest.journey_id == Journey.id)
        .where(
            Journey.user_id == user_id,
            Journey.deleted_at.is_(None),
            JourneyQuest.quest_id == quest_id,
            JourneyQuest.deleted_at.is_(None),
        )
    )
    return (await session.execute(stmt)).scalars().all()


async def progress_summary_map(
    session: AsyncSession, user_id: UUID, journey_ids: list[UUID]
) -> dict[UUID, tuple[int, int]]:
    """여정별 (완료 수, 전체 수)를 집계한다."""
    if not journey_ids:
        return {}
    completed_case = func.count(QuestProgress.id).filter(
        QuestProgress.status == ProgressStatus.COMPLETED.value,
        QuestProgress.deleted_at.is_(None),
    )
    stmt = (
        select(
            JourneyQuest.journey_id,
            completed_case,
            func.count(JourneyQuest.id),
        )
        .outerjoin(
            QuestProgress,
            (QuestProgress.quest_id == JourneyQuest.quest_id) & (QuestProgress.user_id == user_id),
        )
        .where(JourneyQuest.journey_id.in_(journey_ids), JourneyQuest.deleted_at.is_(None))
        .group_by(JourneyQuest.journey_id)
    )
    rows = (await session.execute(stmt)).all()
    return {journey_id: (completed, total) for journey_id, completed, total in rows}
