"""timeline — 사용자 여행 활동 이벤트."""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, String, desc
from sqlalchemy.orm import Mapped, mapped_column

from app.core.base import Base, TimestampMixin, UUIDPKMixin, now_kst


class TimelineEvent(UUIDPKMixin, TimestampMixin, Base):
    __tablename__ = "timeline_events"
    __table_args__ = (Index("ix_timeline_events_user_occurred", "user_id", desc("occurred_at")),)

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    quest_progress_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("quest_progress.id", ondelete="SET NULL")
    )
    event_type: Mapped[str] = mapped_column(String(30))
    title: Mapped[str | None] = mapped_column(String(100))
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_kst)
