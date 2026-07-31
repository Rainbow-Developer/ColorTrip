"""비전 판정 패키지 — 사진 AI 인증 (docs/specs/050-quest-verification/).

get_vision_judge()가 설정에 따라 구현체를 고른다. 판정 제공자를 추가·교체할 때는
이 팩토리만 바꾸면 된다(호출부는 VisionJudge 프로토콜에만 의존).
"""

from app.core.config import settings
from app.integrations.vision.base import VisionJudge, VisionVerdict
from app.integrations.vision.gemini import GeminiVisionJudge
from app.integrations.vision.prompt import build_photo_judgement_prompt
from app.integrations.vision.stub import StubVisionJudge

__all__ = [
    "GeminiVisionJudge",
    "StubVisionJudge",
    "VisionJudge",
    "VisionVerdict",
    "build_photo_judgement_prompt",
    "get_vision_judge",
]


def get_vision_judge() -> VisionJudge:
    """설정에 맞는 비전 판정기를 반환한다 — GEMINI_API_KEY가 없으면 스텁 폴백."""
    if settings.gemini_api_key.strip():
        return GeminiVisionJudge()
    return StubVisionJudge()
