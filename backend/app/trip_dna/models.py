"""trip_dna — 여행 성향 설문과 DNA 결과 이력."""

import uuid
from typing import Any

from sqlalchemy import ForeignKey, Index, Integer, Text, desc
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.core.base import Base, TimestampMixin, UUIDPKMixin
from app.core.enums import dna_type_column


class TripQuestion(UUIDPKMixin, TimestampMixin, Base):
    __tablename__ = "trip_questions"

    question: Mapped[str] = mapped_column(Text)
    sort_order: Mapped[int | None] = mapped_column(Integer)


class TripQuestionOption(UUIDPKMixin, TimestampMixin, Base):
    __tablename__ = "trip_question_options"
    __table_args__ = (Index("ix_trip_question_options_question_id", "question_id"),)

    question_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("trip_questions.id"))
    score_value: Mapped[dict[str, Any]] = mapped_column(JSONB, default=dict)
    content: Mapped[str] = mapped_column(Text)
    category: Mapped[str] = mapped_column(dna_type_column())
    sort_order: Mapped[int | None] = mapped_column(Integer)


class TripReply(UUIDPKMixin, TimestampMixin, Base):
    __tablename__ = "trip_replies"
    __table_args__ = (
        Index("ix_trip_replies_user_id", "user_id"),
        Index("ix_trip_replies_user_created", "user_id", desc("created_at")),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    question_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("trip_questions.id"))
    question_option_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("trip_question_options.id"))


class UserDnaHistory(UUIDPKMixin, TimestampMixin, Base):
    __tablename__ = "user_dna_history"
    __table_args__ = (Index("ix_user_dna_history_user_created", "user_id", desc("created_at")),)

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    dna: Mapped[str] = mapped_column(dna_type_column())
