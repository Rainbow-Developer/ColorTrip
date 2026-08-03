from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import extract, func, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.quests.models import QuestProgress
from app.timeline.models import TimelineEvent
from app.timeline.schemas import TimelineCreate


class TimelineRepository:
    async def create(
        self, session: AsyncSession, obj_in: TimelineCreate
    ) -> tuple[TimelineEvent, bool]:
        """타임라인 레코드를 삽입하고, 중복 완료 이벤트는 기존 행을 반환합니다."""
        if obj_in.quest_progress_id is not None:
            stmt = (
                insert(TimelineEvent)
                .values(
                    user_id=obj_in.user_id,
                    region_id=obj_in.region_id,
                    quest_progress_id=obj_in.quest_progress_id,
                    event_type=obj_in.event_type,
                    title=obj_in.title,
                    occurred_at=obj_in.occurred_at,
                )
                .on_conflict_do_nothing(constraint="uq_timelines_quest_progress_id_event_type")
                .returning(TimelineEvent.id)
            )
            event_id = (await session.execute(stmt)).scalar_one_or_none()
            if event_id is not None:
                event = await session.get(TimelineEvent, event_id)
                assert event is not None
                return event, True
            existing = await session.scalar(
                select(TimelineEvent).where(
                    TimelineEvent.quest_progress_id == obj_in.quest_progress_id,
                    TimelineEvent.event_type == obj_in.event_type,
                )
            )
            assert existing is not None
            return existing, False

        db_obj = TimelineEvent(
            user_id=obj_in.user_id,
            region_id=obj_in.region_id,
            quest_progress_id=obj_in.quest_progress_id,
            event_type=obj_in.event_type,
            title=obj_in.title,
            occurred_at=obj_in.occurred_at,
        )
        session.add(db_obj)
        await session.flush()  # 트랜잭션 내 ID 확보 및 영속화
        return db_obj, True

    async def get_by_user(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        year: int | None = None,
        month: int | None = None,
    ) -> list[TimelineEvent]:
        """특정 유저의 타임라인을 최신순으로 가져옵니다. (KST 시간 범위 기반 인덱스 조회)"""
        query = (
            select(TimelineEvent)
            .options(
                joinedload(TimelineEvent.region),
                joinedload(TimelineEvent.quest_progress).joinedload(QuestProgress.quest),
            )
            .where(TimelineEvent.user_id == user_id)
            .order_by(TimelineEvent.occurred_at.desc())
        )

        # 비즈니스 시간 로직(now_kst)과의 정합성을 위해 KST timezone 객체 사용
        kst_tz = timezone(timedelta(hours=9))

        if year is not None:
            if month is not None:
                start_date = datetime(year, month, 1, tzinfo=kst_tz)
                if month == 12:
                    end_date = datetime(year + 1, 1, 1, tzinfo=kst_tz)
                else:
                    end_date = datetime(year, month + 1, 1, tzinfo=kst_tz)
            else:
                start_date = datetime(year, 1, 1, tzinfo=kst_tz)
                end_date = datetime(year + 1, 1, 1, tzinfo=kst_tz)

            query = query.where(TimelineEvent.occurred_at >= start_date).where(
                TimelineEvent.occurred_at < end_date
            )
        elif month is not None:
            # 연도 없이 월 단독 필터 시 DB 타임존 차이에 따른 오류 방지를 위해 KST 변환 후 추출
            query = query.where(
                extract("month", func.timezone("Asia/Seoul", TimelineEvent.occurred_at)) == month
            )

        result = await session.execute(query)
        return list(result.scalars().all())
