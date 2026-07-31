"""비전 판정 패키지 — 사진 AI 인증 (docs/specs/050-quest-verification/).

get_vision_judge()가 설정에 따라 구현체를 고른다. 판정 제공자를 추가·교체할 때는
이 팩토리만 바꾸면 된다(호출부는 VisionJudge 프로토콜에만 의존).
"""

from app.core.config import settings
from app.integrations.vision.base import VisionJudge, VisionVerdict
from app.integrations.vision.gemini import GeminiVisionJudge
from app.integrations.vision.prompt import build_photo_judgement_prompt
from app.integrations.vision.stub import StubVisionJudge, UnavailableVisionJudge

__all__ = [
    "GeminiVisionJudge",
    "StubVisionJudge",
    "UnavailableVisionJudge",
    "VisionJudge",
    "VisionVerdict",
    "build_photo_judgement_prompt",
    "get_vision_judge",
]

# 키 없이 통과 처리해도 되는 환경 — 그 외에서는 fail-closed로 거부한다.
_STUB_ALLOWED_ENVS = {"local", "test"}


def get_vision_judge() -> VisionJudge:
    """설정에 맞는 비전 판정기를 반환한다.

    키가 있으면 Gemini. 키가 없으면 local·test는 스텁(통과)으로 데모를 가능하게 하고,
    dev·운영은 [UnavailableVisionJudge]로 **거부**한다 — 운영에서 무조건 통과하면
    사진 인증이 없는 것과 같다(fail-closed).
    """
    if settings.gemini_api_key.strip():
        return GeminiVisionJudge()
    if settings.app_env.strip().lower() in _STUB_ALLOWED_ENVS:
        return StubVisionJudge()
    return UnavailableVisionJudge()
