"""journeys — 여정·여정-퀘스트.

테이블 설계: docs/specs/010-journey/description.md (Notion 역동기화 대상)
- 여정은 지역 1개에 속하고, 퀘스트를 journey_quests로 담는다.
- 여정의 모든 퀘스트가 완료되면 status가 completed로 자동 전환된다(plan 의사결정 6).
"""

import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, ForeignKey, Index, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.base import Base, TimestampMixin, UUIDPKMixin
from app.core.enums import JourneyStatus

if TYPE_CHECKING:
    from app.quests.models import Quest
    from app.regions.models import Region


class Journey(UUIDPKMixin, TimestampMixin, Base):
    __tablename__ = "journeys"
    __table_args__ = (Index("ix_journeys_user_status", "user_id", "status"),)

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    region_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("regions.id"))
    title: Mapped[str | None] = mapped_column(String(100))
    status: Mapped[str] = mapped_column(String(20), default=JourneyStatus.IN_PROGRESS.value)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    region: Mapped["Region"] = relationship()
    journey_quests: Mapped[list["JourneyQuest"]] = relationship(
        back_populates="journey", order_by="JourneyQuest.sort_order"
    )


class JourneyQuest(UUIDPKMixin, TimestampMixin, Base):
    __tablename__ = "journey_quests"
    __table_args__ = (
        UniqueConstraint("journey_id", "quest_id", name="uq_journey_quests_journey_id_quest_id"),
    )

    journey_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("journeys.id"))
    quest_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("quests.id"))
    sort_order: Mapped[int] = mapped_column(Integer, default=0)

    journey: Mapped[Journey] = relationship(back_populates="journey_quests")
    quest: Mapped["Quest"] = relationship()
