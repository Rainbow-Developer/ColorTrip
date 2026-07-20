from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqlalchemy import extract, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.timeline.models import TimelineEvent
from app.timeline.schemas import TimelineCreate


class TimelineRepository:
    async def create(self, session: AsyncSession, obj_in: TimelineCreate) -> TimelineEvent:
        """타임라인 레코드를 삽입합니다."""
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
        return db_obj

    async def get_by_user(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        year: int | None = None,
        month: int | None = None,
    ) -> list[TimelineEvent]:
        """특정 유저의 타임라인을 최신순으로 가져옵니다. (날짜 범위 쿼리로 인덱스 스캔 가속)"""
        query = (
            select(TimelineEvent)
            .options(joinedload(TimelineEvent.region))  # 시·군 테이블 조인 로드
            .where(TimelineEvent.user_id == user_id)
            .order_by(TimelineEvent.occurred_at.desc())
        )

        if year is not None:
            # 3.9 호환성을 위해 timezone.utc(UP017 비활성화) 유지
            if month is not None:
                start_date = datetime(year, month, 1, tzinfo=timezone.utc)  # noqa: UP017
                if month == 12:
                    end_date = datetime(year + 1, 1, 1, tzinfo=timezone.utc)  # noqa: UP017
                else:
                    end_date = datetime(year, month + 1, 1, tzinfo=timezone.utc)  # noqa: UP017
            else:
                start_date = datetime(year, 1, 1, tzinfo=timezone.utc)  # noqa: UP017
                end_date = datetime(year + 1, 1, 1, tzinfo=timezone.utc)  # noqa: UP017

            query = (
                query
                .where(TimelineEvent.occurred_at >= start_date)
                .where(TimelineEvent.occurred_at < end_date)
            )
        elif month is not None:
            # 연도가 없고 월만 있는 이례적인 경우에 한해서만 extract 사용
            query = query.where(extract("month", TimelineEvent.occurred_at) == month)

        result = await session.execute(query)
        return list(result.scalars().all())
