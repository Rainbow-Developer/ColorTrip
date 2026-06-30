"""도메인 공통 enum.

카테고리 5종은 퀘스트·DNA·추천이 공유한다(docs/specs/000-quest/plan.md 의사결정 6).
"""

from enum import StrEnum


class Category(StrEnum):
    NATURE = "nature"  # 자연탐험
    FOOD = "food"  # 미식
    HISTORY = "history"  # 역사문화
    ACTIVITY = "activity"  # 액티비티
    HEALING = "healing"  # 힐링


class MissionType(StrEnum):
    GPS_PHOTO = "gps_photo"  # GPS + 사진 인증 (기본)
    QUIZ = "quiz"  # 퀴즈
