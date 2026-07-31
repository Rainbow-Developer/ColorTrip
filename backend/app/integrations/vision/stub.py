"""스텁 비전 판정 — GEMINI_API_KEY 미설정 시 폴백 (docs/specs/050-quest-verification/).

항상 통과 처리하되 사유에 "AI 미설정"을 명시해 실제 판정이 아님을 드러낸다.
"""

from app.integrations.vision.base import VisionVerdict


class StubVisionJudge:
    """키 미설정 환경(로컬·테스트)용 스텁 판정기 — 항상 통과."""

    async def judge(self, image_bytes: bytes, mime_type: str, prompt: str) -> VisionVerdict:
        return VisionVerdict(
            passed=True,
            confidence=0.0,
            reason="AI 판정 미설정(스텁) — GEMINI_API_KEY를 설정하면 실제 판정이 동작합니다.",
            provider="stub",
        )
