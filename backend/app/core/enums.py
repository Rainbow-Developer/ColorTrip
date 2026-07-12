"""도메인 공통 enum.

카테고리 5종은 퀘스트·DNA·추천이 공유한다(docs/specs/000-quest/plan.md 의사결정 6).
"""

from enum import StrEnum

from sqlalchemy import Enum as SQLEnum


class Category(StrEnum):
    NATURE = "nature"  # 자연탐험
    FOOD = "food"  # 미식
    HISTORY = "history"  # 역사문화
    ACTIVITY = "activity"  # 액티비티
    HEALING = "healing"  # 힐링


class DnaType(StrEnum):
    NATURE = "nature"  # 자연탐험
    FOOD = "food"  # 미식
    HISTORY = "history"  # 역사문화
    ACTIVITY = "activity"  # 액티비티
    HEALING = "healing"  # 힐링


DNA_TYPE_VALUES = tuple(dna_type.value for dna_type in DnaType)


def dna_type_column() -> SQLEnum:
    return SQLEnum(*DNA_TYPE_VALUES, name="dna_type", validate_strings=True)


class MissionType(StrEnum):
    GPS_PHOTO = "gps_photo"  # GPS + 사진 인증 (기본)
    QUIZ = "quiz"  # 퀴즈


class ProgressStatus(StrEnum):
    """퀘스트 진행 상태 (quest_progress.status)."""

    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"


class JourneyStatus(StrEnum):
    """여정 상태 (journeys.status) — 모든 퀘스트 완료 시 자동 completed."""

    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
