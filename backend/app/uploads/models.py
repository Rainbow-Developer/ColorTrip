"""사용자별 퀘스트 인증 사진 업로드 이력."""

import uuid

from sqlalchemy import ForeignKey, Index, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.base import Base, TimestampMixin, UUIDPKMixin


class UploadedPhoto(UUIDPKMixin, TimestampMixin, Base):
    __tablename__ = "uploaded_photos"
    __table_args__ = (
        UniqueConstraint("user_id", "photo_url", name="uq_uploaded_photos_user_url"),
        Index("ix_uploaded_photos_user_url", "user_id", "photo_url"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    photo_url: Mapped[str] = mapped_column(String(500), nullable=False)
