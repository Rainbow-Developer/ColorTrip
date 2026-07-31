"""Gemini 비전 판정 구현체 — generateContent(이미지 inline_data + JSON 응답 강제).

규약: docs/conventions/external-apis.md · docs/specs/050-quest-verification/
API 키는 URL이 아닌 x-goog-api-key 헤더로 전달한다(로그 유출 방지).
제공자 교체는 get_vision_judge()(패키지 __init__)에서 한다.
"""

import base64
import json
import logging
import re

import httpx

from app.core.config import settings
from app.core.exceptions import AppException, ErrorCode
from app.integrations.vision.base import VisionVerdict

logger = logging.getLogger(__name__)

_TIMEOUT_SECONDS = 30.0
_PROVIDER = "gemini"


class GeminiVisionJudge:
    """Gemini generateContent 호출로 사진을 판정한다."""

    async def judge(self, image_bytes: bytes, mime_type: str, prompt: str) -> VisionVerdict:
        url = f"{settings.gemini_base_url}/v1beta/models/{settings.gemini_model}:generateContent"
        body = {
            "contents": [
                {
                    "parts": [
                        {
                            "inline_data": {
                                "mime_type": mime_type,
                                "data": base64.b64encode(image_bytes).decode("ascii"),
                            }
                        },
                        {"text": prompt},
                    ]
                }
            ],
            # JSON만 응답하도록 강제한다 — 그래도 마크다운 펜스가 섞이는 경우가 있어
            # 파싱(_parse_verdict_text)은 방어적으로 한다.
            "generationConfig": {"response_mime_type": "application/json"},
        }
        try:
            async with httpx.AsyncClient(timeout=_TIMEOUT_SECONDS) as client:
                response = await client.post(
                    url, json=body, headers={"x-goog-api-key": settings.gemini_api_key}
                )
                response.raise_for_status()
                data = response.json()
        except httpx.HTTPStatusError as exc:
            logger.error(
                "Gemini 판정 호출 실패 (HTTP %s): %s",
                exc.response.status_code,
                exc.response.text[:500],
            )
            raise AppException(
                ErrorCode.INTERNAL_ERROR,
                "AI 판정 서비스 호출에 실패했습니다. 잠시 후 다시 시도해주세요.",
            ) from exc
        except httpx.HTTPError as exc:  # 타임아웃·연결 오류 등
            logger.error("Gemini 판정 호출 실패 (%s): %s", type(exc).__name__, exc)
            raise AppException(
                ErrorCode.INTERNAL_ERROR,
                "AI 판정 서비스에 연결하지 못했습니다. 잠시 후 다시 시도해주세요.",
            ) from exc

        return _parse_verdict(data)


def _parse_verdict(data: dict) -> VisionVerdict:
    """generateContent 응답에서 판정 JSON을 꺼내 VisionVerdict로 변환한다."""
    try:
        text = data["candidates"][0]["content"]["parts"][0]["text"]
    except (KeyError, IndexError, TypeError) as exc:
        logger.error("Gemini 응답에 판정 텍스트가 없습니다: %s", str(data)[:500])
        raise AppException(
            ErrorCode.INTERNAL_ERROR, "AI 판정 응답을 해석하지 못했습니다. 다시 시도해주세요."
        ) from exc
    return _parse_verdict_text(text)


def _parse_passed(raw: object) -> bool:
    """판정 결과를 bool로 해석한다 — 통과는 명시적으로만 인정한다.

    프롬프트로 boolean을 요구하지만 모델이 문자열("false")로 답하는 경우가 있고,
    `bool("false")`는 파이썬에서 True다 — 거절을 통과로 뒤집으면 안 되므로
    True/"true"만 통과로 보고 나머지(문자열·None·숫자·이상값)는 거절로 처리한다.
    """
    if raw is True:
        return True
    if isinstance(raw, str):
        return raw.strip().lower() == "true"
    return False


def _parse_verdict_text(text: str) -> VisionVerdict:
    """판정 텍스트(JSON)를 파싱한다 — 마크다운 펜스·부가 텍스트를 방어적으로 걷어낸다."""
    cleaned = text.strip()
    if cleaned.startswith("```"):
        cleaned = re.sub(r"^```[a-zA-Z]*\s*", "", cleaned)
        cleaned = re.sub(r"\s*```$", "", cleaned)
    try:
        parsed = json.loads(cleaned)
    except json.JSONDecodeError:
        # JSON 앞뒤에 설명이 붙는 경우: 첫 { ... } 블록만 추출해 재시도한다.
        match = re.search(r"\{.*\}", cleaned, re.DOTALL)
        try:
            parsed = json.loads(match.group(0)) if match else None
        except json.JSONDecodeError:
            parsed = None

    if not isinstance(parsed, dict):
        logger.error("Gemini 판정 텍스트 파싱 실패: %s", text[:500])
        raise AppException(
            ErrorCode.INTERNAL_ERROR, "AI 판정 결과를 해석하지 못했습니다. 다시 시도해주세요."
        )

    try:
        confidence = float(parsed.get("confidence", 0.0))
    except (TypeError, ValueError):
        confidence = 0.0
    reason = parsed.get("reason")
    return VisionVerdict(
        passed=_parse_passed(parsed.get("passed")),
        confidence=min(max(confidence, 0.0), 1.0),
        reason=reason
        if isinstance(reason, str) and reason.strip()
        else "판정 사유가 제공되지 않았습니다.",
        provider=_PROVIDER,
    )
