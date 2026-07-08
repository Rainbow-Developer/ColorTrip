"""auth — users and refresh tokens.

규약: docs/specs/005-auth-member/
"""

import uuid
from datetime import date, datetime

from sqlalchemy import Date, DateTime, Enum, ForeignKey, Index, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.base import Base, TimestampMixin, UUIDPKMixin
from app.core.enums import DNA_TYPE_VALUES


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
    email: Mapped[str | None] = mapped_column(String(255))
    nickname: Mapped[str | None] = mapped_column(String(30))
    birth_date: Mapped[date | None] = mapped_column(Date)
    dna: Mapped[str | None] = mapped_column(
        Enum(*DNA_TYPE_VALUES, name="dna_type", validate_strings=True)
    )
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
