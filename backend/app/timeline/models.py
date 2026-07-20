from __future__ import annotations

import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, ForeignKey, Index, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.base import Base, TimestampMixin, UUIDPKMixin

if TYPE_CHECKING:
    from app.auth.models import User
    from app.quests.models import QuestProgress
    from app.regions.models import Region


class TimelineEvent(UUIDPKMixin, TimestampMixin, Base):
    """여행 타임라인 — 사용자별 퀘스트 달성 및 시·군 지도 색칠 발자취 기록.

    정렬/필터링 최적화를 위해 (user_id, occurred_at) 복합 인덱스를 적용합니다.
    """

    __tablename__ = "timelines"
    __table_args__ = (
        Index("ix_timelines_user_occurred", "user_id", "occurred_at"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    region_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("regions.id"), nullable=True
    )
    quest_progress_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("quest_progress.id"), nullable=True
    )
    event_type: Mapped[str] = mapped_column(String(30))  # quest_completed / region_colored 등
    title: Mapped[str | None] = mapped_column(String(100), nullable=True)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))

    user: Mapped[User] = relationship()
    region: Mapped[Region] = relationship()
    quest_progress: Mapped[QuestProgress] = relationship()
