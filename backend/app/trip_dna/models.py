"""trip_dna — 여행 성향 설문과 DNA 결과 이력."""

import uuid

from sqlalchemy import ForeignKey, Index, Integer, Text, desc
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.base import Base, TimestampMixin, UUIDPKMixin
from app.core.enums import dna_type_column


class TripQuestion(UUIDPKMixin, TimestampMixin, Base):
    __tablename__ = "trip_questions"

    question: Mapped[str] = mapped_column(Text, nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    options: Mapped[list["TripQuestionOption"]] = relationship(
        back_populates="question", cascade="all, delete-orphan"
    )


class TripQuestionOption(UUIDPKMixin, TimestampMixin, Base):
    __tablename__ = "trip_question_options"

    question_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("trip_questions.id", ondelete="CASCADE"), nullable=False
    )
    content: Mapped[str] = mapped_column(Text, nullable=False)
    # JSONB 타입 매핑: score_value는 Dict[str, int] 형태로 자동 매핑됩니다.
    score_value: Mapped[dict] = mapped_column(JSONB, default=dict, nullable=False)
    category: Mapped[str | None] = mapped_column(dna_type_column(), nullable=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    # N:1 역관계 정의
    question: Mapped["TripQuestion"] = relationship(back_populates="options")


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
