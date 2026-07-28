"""quests — 데이터 접근 계층 (SQLAlchemy 2.0 async)."""

from collections.abc import Sequence
from typing import Any
from uuid import UUID

from sqlalchemy import ColumnElement, exists, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.enums import ProgressStatus
from app.quests.models import Quest, QuestProgress


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
    filters: list[ColumnElement[bool]] = [
        Quest.deleted_at.is_(None),
        Quest.client_key.is_not(None),
    ]
    if region_id is not None:
        filters.append(Quest.region_id == region_id)
    if category is not None:
        filters.append(Quest.category == category)

    items_stmt = select(Quest).where(*filters).offset((page - 1) * size).limit(size)
    items_result = await session.execute(items_stmt)
    items = items_result.scalars().all()

    count_stmt = select(func.count()).select_from(Quest).where(*filters)
    total = await session.scalar(count_stmt) or 0

    return items, total


async def get_quest(session: AsyncSession, quest_id: UUID) -> Quest | None:
    """단일 퀘스트를 조회한다. soft delete(deleted_at IS NULL) 항목만 반환한다."""
    stmt = select(Quest).where(Quest.id == quest_id, Quest.deleted_at.is_(None))
    return await session.scalar(stmt)


def _completed_by_user(user_id: UUID) -> ColumnElement[bool]:
    return exists().where(
        QuestProgress.quest_id == Quest.id,
        QuestProgress.user_id == user_id,
        QuestProgress.status == ProgressStatus.COMPLETED.value,
        QuestProgress.deleted_at.is_(None),
    )


async def list_recommended(
    session: AsyncSession,
    user_id: UUID,
    region_id: UUID | None,
    preferred_category: str | None,
    page: int,
    size: int,
) -> tuple[Sequence[Quest], int]:
    """추천 퀘스트를 조회한다.

    이미 완료한 퀘스트는 제외하고, 선호 카테고리(=여행 DNA)와 일치하는 퀘스트를 앞에 정렬한다.
    """
    filters: list[ColumnElement[bool]] = [
        Quest.deleted_at.is_(None),
        Quest.client_key.is_not(None),
        ~_completed_by_user(user_id),
    ]
    if region_id is not None:
        filters.append(Quest.region_id == region_id)

    order_by: list[Any] = []
    if preferred_category is not None:
        order_by.append((Quest.category == preferred_category).desc())
    order_by.append(Quest.created_at)

    items_stmt = (
        select(Quest).where(*filters).order_by(*order_by).offset((page - 1) * size).limit(size)
    )
    items = (await session.execute(items_stmt)).scalars().all()

    count_stmt = select(func.count()).select_from(Quest).where(*filters)
    total = await session.scalar(count_stmt) or 0
    return items, total


async def get_progress(
    session: AsyncSession, user_id: UUID, quest_id: UUID
) -> QuestProgress | None:
    """사용자×퀘스트 진행 레코드를 조회한다 (soft delete 제외)."""
    stmt = select(QuestProgress).where(
        QuestProgress.user_id == user_id,
        QuestProgress.quest_id == quest_id,
        QuestProgress.deleted_at.is_(None),
    )
    return await session.scalar(stmt)


async def list_progress(
    session: AsyncSession,
    user_id: UUID,
    status: str | None,
    page: int,
    size: int,
) -> tuple[Sequence[QuestProgress], int]:
    """내 진행/완료 목록을 최신순으로 조회한다 (퀘스트 eager load)."""
    filters: list[ColumnElement[bool]] = [
        QuestProgress.user_id == user_id,
        QuestProgress.deleted_at.is_(None),
    ]
    if status is not None:
        filters.append(QuestProgress.status == status)

    items_stmt = (
        select(QuestProgress)
        .where(*filters)
        .options(selectinload(QuestProgress.quest))
        .order_by(QuestProgress.created_at.desc())
        .offset((page - 1) * size)
        .limit(size)
    )
    items = (await session.execute(items_stmt)).scalars().all()

    count_stmt = select(func.count()).select_from(QuestProgress).where(*filters)
    total = await session.scalar(count_stmt) or 0
    return items, total
