"""journeys — 여정·여정-퀘스트.

테이블 설계: docs/specs/010-journey/description.md (Notion 역동기화 대상)
- 여정은 지역 1개에 속하고, 퀘스트를 journey_quests로 담는다.
- status는 완료 판정 규칙에서 파생·저장된다: 퀘스트 전부 완료, 또는 기간 경과(end_date <
  오늘 KST) + 완료 퀘스트 1개 이상 (description.md#여정-완료-판정).
"""

import uuid
from datetime import date, datetime
from typing import TYPE_CHECKING

from sqlalchemy import Date, DateTime, ForeignKey, Index, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.base import Base, TimestampMixin, UUIDPKMixin
from app.core.enums import JourneyStatus

if TYPE_CHECKING:
    from app.quests.models import Quest
    from app.regions.models import Region


class Journey(UUIDPKMixin, TimestampMixin, Base):
    __tablename__ = "journeys"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "client_request_id",
            name="uq_journeys_user_id_client_request_id",
        ),
        Index("ix_journeys_user_status", "user_id", "status"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    client_request_id: Mapped[uuid.UUID | None]
    region_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("regions.id"))
    title: Mapped[str | None] = mapped_column(String(100))
    start_date: Mapped[date | None] = mapped_column(Date)
    end_date: Mapped[date | None] = mapped_column(Date)
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
