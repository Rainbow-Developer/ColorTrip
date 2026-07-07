"""quests — 지역별 퀘스트.

테이블 설계: docs/specs/000-quest/ (Notion 동기화)
- category: 문자열 enum(Category 5종) 검증은 앱 레벨 (의사결정 6)
- mission_meta: 미션 타입별 부가데이터 JSONB (의사결정 7)
- 운영정보(시간·휴무 등)는 저장하지 않고 content_id로 TourAPI 조회 (의사결정 5)
"""

import uuid
from decimal import Decimal
from typing import TYPE_CHECKING, Any

from sqlalchemy import ForeignKey, Index, Integer, Numeric, String, Text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.base import Base, TimestampMixin, UUIDPKMixin
from app.core.enums import MissionType

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
