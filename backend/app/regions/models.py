"""regions — 충북 시·군 마스터 (11행).

테이블 설계: docs/specs/000-quest/ (Notion 동기화)
"""

from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import Numeric, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.base import Base, TimestampMixin, UUIDPKMixin

if TYPE_CHECKING:
    from app.quests.models import Quest


class Region(UUIDPKMixin, TimestampMixin, Base):
    __tablename__ = "regions"
    __table_args__ = (UniqueConstraint("slug", name="uq_regions_slug"),)

    name: Mapped[str] = mapped_column(String(30))  # 청주시, 단양군 …
    slug: Mapped[str | None] = mapped_column(String(30))
    area_code: Mapped[str | None] = mapped_column(String(20), unique=True)  # sigunguCode
    center_lat: Mapped[Decimal | None] = mapped_column(Numeric(10, 7))
    center_lng: Mapped[Decimal | None] = mapped_column(Numeric(10, 7))

    quests: Mapped[list["Quest"]] = relationship(back_populates="region")
