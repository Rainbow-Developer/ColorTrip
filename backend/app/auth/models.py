"""auth — users and refresh tokens.

규약: docs/specs/005-auth-member/
"""

import uuid
from datetime import date, datetime

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Index,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.base import Base, TimestampMixin, UUIDPKMixin, now_kst
from app.core.enums import dna_type_column


class User(UUIDPKMixin, TimestampMixin, Base):
    __tablename__ = "users"
    __table_args__ = (
        UniqueConstraint(
            "social_provider",
            "social_id",
            name="uq_users_social_provider_social_id",
        ),
    )

    social_provider: Mapped[str] = mapped_column(String(20))
    social_id: Mapped[str] = mapped_column(String(100))
    nickname: Mapped[str | None] = mapped_column(String(30))
    birth_date: Mapped[date | None] = mapped_column(Date)
    dna: Mapped[str | None] = mapped_column(dna_type_column())
    profile_image: Mapped[str | None] = mapped_column(String(500))
    withdrawal_grace_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    anonymized_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    refresh_tokens: Mapped[list["RefreshToken"]] = relationship(back_populates="user")


class RefreshToken(UUIDPKMixin, TimestampMixin, Base):
    __tablename__ = "refresh_tokens"
    __table_args__ = (
        Index("ix_refresh_tokens_user_id", "user_id"),
        Index("ix_refresh_tokens_token_hash", "token_hash", unique=True),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    token_hash: Mapped[str] = mapped_column(String(255))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))

    user: Mapped[User] = relationship(back_populates="refresh_tokens")


class UserConsent(UUIDPKMixin, Base):
    __tablename__ = "user_consents"
    __table_args__ = (
        CheckConstraint(
            "consent_type IN ('terms', 'privacy')",
            name="ck_user_consents_type",
        ),
        UniqueConstraint(
            "user_id",
            "consent_type",
            "version",
            name="uq_user_consents_user_type_version",
        ),
        Index("ix_user_consents_user_id", "user_id"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    consent_type: Mapped[str] = mapped_column(String(20), nullable=False)
    version: Mapped[str] = mapped_column(String(50), nullable=False)
    agreed: Mapped[bool] = mapped_column(Boolean, nullable=False)
    decided_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    document_digest: Mapped[str] = mapped_column(String(64), nullable=False)
    source: Mapped[str] = mapped_column(String(30), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_kst)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=now_kst, onupdate=now_kst
    )
