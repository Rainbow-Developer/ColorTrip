"""open_api — 지자체 통계 집계 쿼리 (SQLAlchemy 2.0 async).

지역 단위 집계만 다루며, 개인 식별 값(닉네임·생년월일 등)은 어떤 쿼리도 반환하지 않는다
(docs/specs/070-municipal-open-api/plan.md).
"""

from collections.abc import Sequence
from datetime import datetime
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.models import User
from app.core.enums import JourneyStatus, ProgressStatus
from app.journeys.models import Journey
from app.quests.models import Quest, QuestProgress
from app.regions.models import Region
from app.shares.models import Share


async def get_region_by_slug(session: AsyncSession, slug: str) -> Region | None:
    stmt = select(Region).where(Region.slug == slug, Region.deleted_at.is_(None))
    result = await session.execute(stmt)
    return result.scalar_one_or_none()


async def count_completed_quests(session: AsyncSession, region_id: UUID) -> int:
    stmt = (
        select(func.count(QuestProgress.id))
        .join(Quest, Quest.id == QuestProgress.quest_id)
        .where(
            Quest.region_id == region_id,
            QuestProgress.status == ProgressStatus.COMPLETED.value,
            QuestProgress.deleted_at.is_(None),
        )
    )
    return (await session.execute(stmt)).scalar_one()


async def monthly_completed_quest_counts(
    session: AsyncSession, region_id: UUID, since: datetime
) -> Sequence[tuple[str, int]]:
    month = func.to_char(QuestProgress.completed_at, "YYYY-MM")
    stmt = (
        select(month, func.count(QuestProgress.id))
        .join(Quest, Quest.id == QuestProgress.quest_id)
        .where(
            Quest.region_id == region_id,
            QuestProgress.status == ProgressStatus.COMPLETED.value,
            QuestProgress.deleted_at.is_(None),
            QuestProgress.completed_at >= since,
        )
        .group_by(month)
        .order_by(month)
    )
    rows = (await session.execute(stmt)).all()
    return [(month_label, count) for month_label, count in rows]


async def top_popular_spots(
    session: AsyncSession, region_id: UUID, limit: int = 10
) -> Sequence[tuple[UUID, str, int]]:
    count = func.count(QuestProgress.id)
    stmt = (
        select(Quest.id, Quest.title, count)
        .join(QuestProgress, QuestProgress.quest_id == Quest.id)
        .where(
            Quest.region_id == region_id,
            QuestProgress.status == ProgressStatus.COMPLETED.value,
            QuestProgress.deleted_at.is_(None),
        )
        .group_by(Quest.id, Quest.title)
        .order_by(count.desc())
        .limit(limit)
    )
    rows = (await session.execute(stmt)).all()
    return [(quest_id, title, count) for quest_id, title, count in rows]


async def verification_method_breakdown(
    session: AsyncSession, region_id: UUID
) -> Sequence[tuple[str, int]]:
    stmt = (
        select(Quest.mission_type, func.count(QuestProgress.id))
        .join(QuestProgress, QuestProgress.quest_id == Quest.id)
        .where(
            Quest.region_id == region_id,
            QuestProgress.status == ProgressStatus.COMPLETED.value,
            QuestProgress.deleted_at.is_(None),
        )
        .group_by(Quest.mission_type)
    )
    rows = (await session.execute(stmt)).all()
    return [(mission_type, count) for mission_type, count in rows]


async def dna_distribution(session: AsyncSession, region_id: UUID) -> Sequence[tuple[str, int]]:
    """그 지역에서 퀘스트를 완료한 적 있는(distinct) 사용자의 DNA 유형 분포.

    DNA가 아직 없는(설문 미완료) 사용자는 분포 계산에서 제외한다.
    """
    visitor_ids = (
        select(QuestProgress.user_id)
        .join(Quest, Quest.id == QuestProgress.quest_id)
        .where(
            Quest.region_id == region_id,
            QuestProgress.status == ProgressStatus.COMPLETED.value,
            QuestProgress.deleted_at.is_(None),
        )
        .distinct()
        .subquery()
    )
    stmt = (
        select(User.dna, func.count(User.id))
        .where(User.id.in_(select(visitor_ids)), User.dna.is_not(None))
        .group_by(User.dna)
    )
    rows = (await session.execute(stmt)).all()
    return [(dna, count) for dna, count in rows if dna is not None]


async def journey_completion_stats(
    session: AsyncSession, region_id: UUID
) -> tuple[int, int, float | None]:
    """(시작 수, 완료 수, 평균 완주 소요일수)를 반환한다. 완료 건이 없으면 평균은 None.

    세 번 나눠 조회하지 않고 조건부 집계(FILTER) 하나로 묶는다 — region의 journeys를
    3번 스캔할 필요가 없다.
    """
    is_completed = Journey.status == JourneyStatus.COMPLETED.value
    # Postgres의 date - date는 정수(일수)를 반환한다 — completed_at(timestamptz)을
    # date로 캐스팅해 start_date(date)와 그대로 뺄셈한다.
    avg_days_expr = func.avg(func.date(Journey.completed_at) - Journey.start_date).filter(
        is_completed,
        Journey.start_date.is_not(None),
        Journey.completed_at.is_not(None),
    )
    stmt = select(
        func.count(Journey.id),
        func.count(Journey.id).filter(is_completed),
        avg_days_expr,
    ).where(Journey.region_id == region_id, Journey.deleted_at.is_(None))
    started, completed, avg_days = (await session.execute(stmt)).one()
    return started, completed, float(avg_days) if avg_days is not None else None


async def share_counts_by_style(
    session: AsyncSession, region_id: UUID
) -> Sequence[tuple[str, int]]:
    """공유 생성 시점의 대표 지역(Share.region_id) 기준 스타일별 공유 수."""
    stmt = (
        select(Share.share_style, func.count(Share.id))
        .where(Share.region_id == region_id, Share.deleted_at.is_(None))
        .group_by(Share.share_style)
    )
    rows = (await session.execute(stmt)).all()
    return [(style, count) for style, count in rows]
