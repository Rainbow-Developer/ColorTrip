"""quests — 데이터 접근 계층 (SQLAlchemy 2.0 async)."""

from collections.abc import Sequence
from uuid import UUID

from sqlalchemy import ColumnElement, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.quests.models import Quest


async def list_quests(
    session: AsyncSession,
    region_id: UUID | None,
    category: str | None,
    page: int,
    size: int,
) -> tuple[Sequence[Quest], int]:
    """필터(region_id·category, 있을 때만)와 offset 페이지네이션으로 퀘스트를 조회한다.

    soft delete(deleted_at IS NULL) 항목만 포함하며, total은 동일 필터의 전체 개수다.
    """
    filters: list[ColumnElement[bool]] = [Quest.deleted_at.is_(None)]
    if region_id is not None:
        filters.append(Quest.region_id == region_id)
    if category is not None:
        filters.append(Quest.category == category)

    items_stmt = (
        select(Quest)
        .where(*filters)
        .offset((page - 1) * size)
        .limit(size)
    )
    items_result = await session.execute(items_stmt)
    items = items_result.scalars().all()

    count_stmt = select(func.count()).select_from(Quest).where(*filters)
    total = await session.scalar(count_stmt) or 0

    return items, total


async def get_quest(session: AsyncSession, quest_id: UUID) -> Quest | None:
    """단일 퀘스트를 조회한다. soft delete(deleted_at IS NULL) 항목만 반환한다."""
    stmt = select(Quest).where(Quest.id == quest_id, Quest.deleted_at.is_(None))
    return await session.scalar(stmt)
