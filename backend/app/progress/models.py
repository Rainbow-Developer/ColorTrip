"""progress — 사용자별 지역 색칠/진행 집계."""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, Integer, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.base import Base, TimestampMixin, UUIDPKMixin


class MapProgress(UUIDPKMixin, TimestampMixin, Base):
    __tablename__ = "map_progress"
    __table_args__ = (
        UniqueConstraint("user_id", "region_id", name="uq_map_progress_user_region"),
        Index("ix_map_progress_user_id", "user_id"),
        Index("ix_map_progress_region_id", "region_id"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    region_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("regions.id"))
    completed_count: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    first_colored_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
