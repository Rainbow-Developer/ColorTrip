"""비전 판정 추상화 — docs/specs/050-quest-verification/

사진 AI 인증의 판정 제공자(Gemini 등)를 교체 가능한 인터페이스 뒤에 숨긴다.
구현체 선택은 get_vision_judge()(패키지 __init__)가 담당한다.
"""

from typing import Protocol

from pydantic import BaseModel, Field


class VisionVerdict(BaseModel):
    """사진 판정 결과."""

    passed: bool
    confidence: float = Field(ge=0.0, le=1.0)  # 0~1 신뢰도
    reason: str  # 판정 근거 (한국어 한두 문장)
    provider: str  # 판정 제공자 (gemini / stub)


class VisionJudge(Protocol):
    """사진 판정 제공자 인터페이스."""

    async def judge(self, image_bytes: bytes, mime_type: str, prompt: str) -> VisionVerdict:
        """이미지와 판정 프롬프트를 받아 판정 결과를 반환한다."""
        ...
