from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import case, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.core.base import new_uuid7, now_kst
from app.progress.models import MapProgress
from app.quests.models import Quest
from app.timeline import repository
from app.timeline.models import TimelineEvent
from app.timeline.schemas import TimelineCreate, TimelineRead


async def create_timeline_event(
    session: AsyncSession,
    user_id: uuid.UUID,
    event_type: str,
    region_id: uuid.UUID | None = None,
    quest_progress_id: uuid.UUID | None = None,
    title: str | None = None,
    occurred_at: datetime | None = None,
) -> TimelineEvent:
    """타임라인 이벤트를 적재합니다."""
    if occurred_at is None:
        occurred_at = now_kst()

    obj_in = TimelineCreate(
        user_id=user_id,
        region_id=region_id,
        quest_progress_id=quest_progress_id,
        event_type=event_type,
        title=title,
        occurred_at=occurred_at,
    )
    repo = repository.TimelineRepository()
    return await repo.create(session, obj_in)


async def get_user_timeline(
    session: AsyncSession,
    user_id: uuid.UUID,
    year: int | None = None,
    month: int | None = None,
) -> list[TimelineRead]:
    """유저의 타임라인 기록 목록을 읽어옵니다. (연/월 필터링 적용)"""
    repo = repository.TimelineRepository()
    db_items = await repo.get_by_user(session, user_id, year=year, month=month)

    # ORM 객체 ➔ Pydantic 스키마 변환 및 조인된 시·군 이름 파싱
    return [
        TimelineRead(
            id=item.id,
            event_type=item.event_type,
            title=item.title,
            region_name=item.region.name if item.region else None,
            occurred_at=item.occurred_at,
        )
        for item in db_items
    ]


async def handle_quest_completion(
    session: AsyncSession,
    user_id: uuid.UUID,
    quest_id: uuid.UUID,
    quest_progress_id: uuid.UUID,
) -> None:
    """퀘스트 성공 완료 시 호출되어 MapProgress를 업데이트하고
    관련 타임라인 이벤트를 자동 적재합니다.
    """
    # 1. 퀘스트 정보 및 소속 지역 조회
    quest_result = await session.execute(
        select(Quest).where(Quest.id == quest_id).options(joinedload(Quest.region))
    )
    quest = quest_result.scalars().first()
    if not quest:
        return

    region_id = quest.region_id
    region_name = quest.region.name if quest.region else ""
    completed_at = now_kst()

    # 2. MapProgress를 단일 UPSERT로 증가시켜 같은 지역의 동시 완료를 직렬화한다.
    map_progress_stmt = (
        insert(MapProgress)
        .values(
            id=new_uuid7(),
            user_id=user_id,
            region_id=region_id,
            completed_count=1,
            first_colored_at=completed_at,
            created_at=completed_at,
            updated_at=completed_at,
            deleted_at=None,
        )
        .on_conflict_do_update(
            constraint="uq_map_progress_user_region",
            set_={
                "completed_count": MapProgress.completed_count + 1,
                "first_colored_at": case(
                    (MapProgress.completed_count == 0, completed_at),
                    else_=MapProgress.first_colored_at,
                ),
                "updated_at": completed_at,
                "deleted_at": None,
            },
        )
        .returning(MapProgress.completed_count)
    )
    completed_count = (await session.execute(map_progress_stmt)).scalar_one()
    is_first_color = completed_count == 1

    # 3. 타임라인 기록 생성
    # 3-1. 최초 색칠 성공 시 'region_colored' 이벤트 생성
    if is_first_color:
        await create_timeline_event(
            session=session,
            user_id=user_id,
            event_type="region_colored",
            region_id=region_id,
            title=f"{region_name} 색칠 성공!",
            occurred_at=completed_at,
        )

    # 3-2. 'quest_completed' 이벤트 생성
    await create_timeline_event(
        session=session,
        user_id=user_id,
        event_type="quest_completed",
        region_id=region_id,
        quest_progress_id=quest_progress_id,
        title=quest.title,
        occurred_at=completed_at,
    )
