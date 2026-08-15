"""QR 서명·Gemini 판정 파싱 단위 테스트 (docs/specs/050-quest-verification/).

사진·QR 인증은 `POST /quests/{id}/verify` 한 경로로만 수행하므로(KAN-73) 판정 전용
엔드포인트 테스트는 `test_quest_verification.py`로 옮겨졌다."""

import pytest

from app.integrations.vision.gemini import _parse_verdict_text
from app.verifications.service import sign_quest_payload, verify_qr_payload

# --- QR 서명 (단위) ---


def test_qr_sign_and_verify_roundtrip() -> None:
    payload = sign_quest_payload("dy3")
    assert payload.startswith("colortrip:quest:dy3:")

    passed, reason = verify_qr_payload(payload, "dy3")
    assert passed is True
    assert reason


def test_qr_tampered_signature_fails() -> None:
    payload = sign_quest_payload("dy3")
    tampered = payload[:-1] + ("0" if payload[-1] != "0" else "1")

    passed, reason = verify_qr_payload(tampered, "dy3")
    assert passed is False
    assert "위조" in reason


def test_qr_quest_id_swap_keeps_signature_invalid() -> None:
    # 페이로드의 quest_id만 바꿔치기해도 서명이 깨진다.
    signature = sign_quest_payload("dy3").rsplit(":", 1)[1]
    forged = f"colortrip:quest:cj1:{signature}"

    passed, reason = verify_qr_payload(forged, "cj1")
    assert passed is False
    assert "위조" in reason


def test_qr_for_other_quest_fails() -> None:
    other_payload = sign_quest_payload("cj1")  # 다른 퀘스트의 정상 QR

    passed, reason = verify_qr_payload(other_payload, "dy3")
    assert passed is False
    assert "이 퀘스트의 QR" in reason


@pytest.mark.parametrize(
    "bad_payload",
    ["", "https://example.com", "colortrip:quest:dy3", "colortrip:quest::abcd1234"],
)
def test_qr_malformed_payload_fails(bad_payload: str) -> None:
    passed, _reason = verify_qr_payload(bad_payload, "dy3")
    assert passed is False


# --- Gemini 판정 텍스트 파싱 (단위) ---


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ('{"passed": true, "confidence": 0.9, "reason": "확인됨"}', True),
        ('{"passed": "true", "confidence": 0.9, "reason": "확인됨"}', True),
        # bool("false")는 파이썬에서 True다 — 거절이 통과로 뒤집히면 안 된다.
        ('{"passed": "false", "confidence": 0.9, "reason": "조건 불일치"}', False),
        ('{"passed": false, "confidence": 0.1, "reason": "조건 불일치"}', False),
        ('{"passed": null, "confidence": 0.1, "reason": "모호함"}', False),
        ('{"confidence": 0.5, "reason": "필드 누락"}', False),
        # 마크다운 펜스·부가 설명이 섞여도 통과 여부는 그대로 해석한다.
        ('```json\n{"passed": "FALSE", "confidence": 0.2, "reason": "불일치"}\n```', False),
    ],
)
def test_parse_verdict_text_only_accepts_explicit_true(raw: str, expected: bool) -> None:
    verdict = _parse_verdict_text(raw)
    assert verdict.passed is expected
    assert 0.0 <= verdict.confidence <= 1.0
    assert verdict.reason


@pytest.mark.asyncio
async def test_gemini_api_key_is_stripped_before_becoming_a_header(monkeypatch) -> None:
    """줄바꿈이 딸려 저장된 키로도 요청이 나가야 한다 (KAN-75).

    Secret Manager에 키를 넣을 때 터미널에서 Enter로 입력하면 끝에 개행이 붙는다.
    그대로 헤더 값에 넣으면 httpx가 헤더 주입으로 보고 요청 자체를 거부해, 원인을
    찾기 어려운 500이 된다.
    """
    import httpx

    from app.core.config import settings
    from app.integrations.vision.gemini import GeminiVisionJudge

    monkeypatch.setattr(settings, "gemini_api_key", "test-key\n", raising=False)
    seen: dict[str, str] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        seen["key"] = request.headers["x-goog-api-key"]
        return httpx.Response(
            200,
            json={
                "candidates": [
                    {
                        "content": {
                            "parts": [
                                {
                                    "text": (
                                        '{"passed": true, "confidence": 0.9, "reason": "확인됨"}'
                                    )
                                }
                            ]
                        }
                    }
                ]
            },
        )

    transport = httpx.MockTransport(handler)
    original_client = httpx.AsyncClient

    def patched_client(*args, **kwargs):
        kwargs["transport"] = transport
        return original_client(*args, **kwargs)

    monkeypatch.setattr(httpx, "AsyncClient", patched_client)

    verdict = await GeminiVisionJudge().judge(b"bytes", "image/jpeg", "prompt")

    assert seen["key"] == "test-key"
    assert verdict.passed is True
