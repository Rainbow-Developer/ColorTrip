import uuid
from sqlalchemy import ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.base import Base, TimestampMixin, UUIDPKMixin


class TripQuestion(UUIDPKMixin, TimestampMixin, Base):
    __tablename__ = "trip_questions"

    question: Mapped[str] = mapped_column(Text, nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    # 1:N 관계 정의 - 질문 하나는 여러 개의 선택지(options)를 가질 수 있습니다.
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
    score_value: Mapped[dict] = mapped_column(JSONB, nullable=False)
    category: Mapped[str | None] = mapped_column(String(20), nullable=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    # N:1 역관계 정의
    question: Mapped["TripQuestion"] = relationship(back_populates="options")