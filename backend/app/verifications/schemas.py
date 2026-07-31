"""verifications — API 입출력 스키마 (pydantic v2)."""

from pydantic import BaseModel, Field


class PhotoVerifyData(BaseModel):
    """사진 AI 판정 결과."""

    passed: bool
    confidence: float  # 0~1 신뢰도 (스텁 판정은 0.0)
    reason: str  # 판정 근거 (한국어)
    provider: str  # 판정 제공자 (gemini / stub)


class QrVerifyRequest(BaseModel):
    """QR 인증 요청 — 스캔한 페이로드와 인증하려는 퀘스트 id.

    길이 상한은 페이로드 형식(`colortrip:quest:{id}:{서명 16자}`) 기준의 여유값이다 —
    사진 업로드처럼 과대 입력 자체를 파싱 전에 막는다.
    """

    payload: str = Field(max_length=256)
    quest_id: str = Field(max_length=64)


class QrVerifyData(BaseModel):
    """QR 서명 검증 결과."""

    passed: bool
    reason: str
