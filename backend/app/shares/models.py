from __future__ import annotations

import uuid
from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, Index, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.base import Base, TimestampMixin, UUIDPKMixin

if TYPE_CHECKING:
    from app.auth.models import User


class Share(UUIDPKMixin, TimestampMixin, Base):
    """여행 공유 카드 — 사용자별 카드 스타일 및 숏코드 저장 모델."""

    __tablename__ = "shares"
    __table_args__ = (
        UniqueConstraint("share_code", name="uq_shares_share_code"),
        Index("ix_shares_share_code", "share_code", unique=True),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    share_code: Mapped[str] = mapped_column(String(16), unique=True)
    share_style: Mapped[str] = mapped_column(String(20))  # MAP_AND_DNA / MAP / DNA

    # 공유 생성 시점에 사용자의 완료 퀘스트 수가 가장 많은 지역("대표 지역")을 스냅샷으로
    # 저장한다 — 지자체 오픈 API의 지역별 공유 통계가 이 값을 근거로 집계한다
    # (docs/specs/070-municipal-open-api). 색칠 지역이 아예 없으면 None.
    region_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("regions.id"))

    user: Mapped[User] = relationship()
