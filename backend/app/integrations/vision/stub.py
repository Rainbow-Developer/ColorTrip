"""키 미설정 시의 비전 판정 대체 구현 (docs/specs/050-quest-verification/).

- [StubVisionJudge]: **local·test 전용**. 항상 통과하되 사유에 "AI 미설정"을 명시해
  실제 판정이 아님을 드러낸다 — 키 없이도 데모·테스트가 가능해야 하기 때문이다.
- [UnavailableVisionJudge]: 그 외 환경(dev·운영). 키가 없으면 **거부**한다(fail-closed).
  운영에서 스텁이 무조건 통과하면 사진 인증이 사실상 없는 것과 같다.

어느 구현이 쓰이는지는 `get_vision_judge()`가 APP_ENV로 결정한다.
"""

from app.integrations.vision.base import VisionVerdict


class StubVisionJudge:
    """local·test용 스텁 판정기 — 항상 통과."""

    async def judge(self, image_bytes: bytes, mime_type: str, prompt: str) -> VisionVerdict:
        return VisionVerdict(
            passed=True,
            confidence=0.0,
            reason="AI 판정 미설정(스텁) — GEMINI_API_KEY를 설정하면 실제 판정이 동작합니다.",
            provider="stub",
        )


class UnavailableVisionJudge:
    """운영·dev에서 키가 없을 때의 fail-closed 판정기 — 항상 거부."""

    async def judge(self, image_bytes: bytes, mime_type: str, prompt: str) -> VisionVerdict:
        return VisionVerdict(
            passed=False,
            confidence=0.0,
            reason="지금은 사진 인증을 처리할 수 없어요. 잠시 후 다시 시도해주세요.",
            provider="unavailable",
        )
