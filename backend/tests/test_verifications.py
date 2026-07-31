"""스테이트리스 인증 API·QR 서명 테스트 (docs/specs/050-quest-verification/)."""

import pytest
from httpx import AsyncClient

from app.core.config import settings
from app.integrations.vision.gemini import _parse_verdict_text
from app.verifications.service import sign_quest_payload, verify_qr_payload
from tests.helpers import auth_headers

_PNG_BYTES = b"\x89PNG\r\n\x1a\n" + b"0" * 32


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


# --- POST /api/v1/verifications/qr ---


async def test_verify_qr_endpoint(client: AsyncClient) -> None:
    headers = await auth_headers(client)
    payload = sign_quest_payload("dy3")

    ok = await client.post(
        "/api/v1/verifications/qr",
        json={"payload": payload, "quest_id": "dy3"},
        headers=headers,
    )
    assert ok.status_code == 200
    assert ok.json()["data"]["passed"] is True

    wrong = await client.post(
        "/api/v1/verifications/qr",
        json={"payload": payload, "quest_id": "cj1"},
        headers=headers,
    )
    assert wrong.status_code == 200
    data = wrong.json()["data"]
    assert data["passed"] is False
    assert "이 퀘스트의 QR" in data["reason"]


async def test_verify_qr_requires_auth(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/verifications/qr",
        json={"payload": sign_quest_payload("dy3"), "quest_id": "dy3"},
    )
    assert response.status_code == 401


# --- POST /api/v1/verifications/photo ---


async def test_verify_photo_stub_judgement(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    # 로컬 .env에 GEMINI_API_KEY가 있어도 스텁 판정을 검증하도록 고정한다.
    monkeypatch.setattr(settings, "gemini_api_key", "")
    headers = await auth_headers(client)

    response = await client.post(
        "/api/v1/verifications/photo",
        files={"image": ("visit.png", _PNG_BYTES, "image/png")},
        data={
            "title": "도담삼봉 인증샷",
            "place": "도담삼봉",
            "conditions": "도담삼봉에서 촬영\n주변 풍경이 보이는 구도",
        },
        headers=headers,
    )
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["provider"] == "stub"
    assert data["passed"] is True
    assert data["confidence"] == 0.0
    assert "AI 판정 미설정" in data["reason"]


async def test_verify_photo_rejects_non_image(client: AsyncClient) -> None:
    headers = await auth_headers(client)

    response = await client.post(
        "/api/v1/verifications/photo",
        files={"image": ("note.txt", b"hello", "text/plain")},
        data={"title": "도담삼봉 인증샷", "place": "도담삼봉"},
        headers=headers,
    )
    assert response.status_code == 422


async def test_verify_photo_rejects_oversized(client: AsyncClient) -> None:
    headers = await auth_headers(client)
    oversized = b"\x89PNG\r\n\x1a\n" + b"0" * (settings.max_upload_size_mb * 1024 * 1024 + 1)

    response = await client.post(
        "/api/v1/verifications/photo",
        files={"image": ("big.png", oversized, "image/png")},
        data={"title": "도담삼봉 인증샷", "place": "도담삼봉"},
        headers=headers,
    )
    assert response.status_code == 422


async def test_verify_photo_requires_auth(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/verifications/photo",
        files={"image": ("visit.png", _PNG_BYTES, "image/png")},
        data={"title": "도담삼봉 인증샷", "place": "도담삼봉"},
    )
    assert response.status_code == 401


# --- Gemini 판정 텍스트 파싱 (제공자 응답이 지시를 어길 때의 안전성) ---


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


async def test_verify_qr_rejects_oversized_payload(client: AsyncClient) -> None:
    headers = await auth_headers(client)

    response = await client.post(
        "/api/v1/verifications/qr",
        json={"payload": "colortrip:quest:" + "0" * 500, "quest_id": "dy3"},
        headers=headers,
    )
    assert response.status_code == 422
