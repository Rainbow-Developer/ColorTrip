"""quests — 지역별 퀘스트.

테이블 설계: docs/specs/000-quest/ (Notion 동기화)
- category: 문자열 enum(Category 5종) 검증은 앱 레벨 (의사결정 6)
- mission_meta: 미션 타입별 부가데이터 JSONB (의사결정 7)
- 운영정보(시간·휴무 등)는 저장하지 않고 content_id로 TourAPI 조회 (의사결정 5)
"""

import uuid
from datetime import datetime
from decimal import Decimal
from typing import TYPE_CHECKING, Any

from sqlalchemy import DateTime, ForeignKey, Index, Integer, Numeric, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.base import Base, TimestampMixin, UUIDPKMixin
from app.core.enums import MissionType, ProgressStatus

if TYPE_CHECKING:
    from app.regions.models import Region


class Quest(UUIDPKMixin, TimestampMixin, Base):
    __tablename__ = "quests"
    __table_args__ = (Index("ix_quests_region_category", "region_id", "category"),)

    region_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("regions.id"))
    title: Mapped[str] = mapped_column(String(100))
    description: Mapped[str | None] = mapped_column(Text)
    category: Mapped[str] = mapped_column(String(20))  # Category 값
    mission_type: Mapped[str] = mapped_column(String(30), default=MissionType.GPS_PHOTO.value)
    mission_meta: Mapped[dict[str, Any] | None] = mapped_column(JSONB)
    content_id: Mapped[str | None] = mapped_column(String(50))  # TourAPI contentId
    content_type_id: Mapped[str | None] = mapped_column(String(20))  # TourAPI contentTypeId
    lat: Mapped[Decimal | None] = mapped_column(Numeric(10, 7))
    lng: Mapped[Decimal | None] = mapped_column(Numeric(10, 7))
    verify_radius: Mapped[int] = mapped_column(Integer, default=200)  # GPS 인증 반경(m)
    thumbnail_url: Mapped[str | None] = mapped_column(String(500))

    region: Mapped["Region"] = relationship(back_populates="quests")


class QuestProgress(UUIDPKMixin, TimestampMixin, Base):
    """퀘스트 진행/인증 — 사용자×퀘스트당 1개 (docs/specs/010-journey/).

    journey_id는 어느 여정에서 수행했는지 추적용(선택). 완료 기록은 지도 색칠(MAP)·
    타임라인(SHR) 도메인이 소비한다.
    """

    __tablename__ = "quest_progress"
    __table_args__ = (
        UniqueConstraint("user_id", "quest_id", name="uq_quest_progress_user_id_quest_id"),
        Index("ix_quest_progress_user_status", "user_id", "status"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    quest_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("quests.id"))
    journey_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("journeys.id"))
    status: Mapped[str] = mapped_column(String(20), default=ProgressStatus.IN_PROGRESS.value)
    verified_lat: Mapped[Decimal | None] = mapped_column(Numeric(10, 7))
    verified_lng: Mapped[Decimal | None] = mapped_column(Numeric(10, 7))
    photo_url: Mapped[str | None] = mapped_column(String(500))
    quiz_answer: Mapped[str | None] = mapped_column(String(200))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    quest: Mapped[Quest] = relationship()
