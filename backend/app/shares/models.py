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

    user: Mapped[User] = relationship()
