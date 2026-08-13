"""verifications — 스테이트리스 인증 로직 (docs/specs/050-quest-verification/).

- 사진: 퀘스트 맥락 프롬프트를 만들어 비전 판정기에 위임한다.
- QR: HMAC-SHA256 서명 페이로드(colortrip:quest:{id}:{서명 16자})를 생성·검증한다.
  DB 퀘스트 인증(app/quests/verification.py)도 verify_qr_payload를 재사용한다.
"""

import hashlib
import hmac

from app.core.config import settings
from app.integrations.vision import build_photo_judgement_prompt, get_vision_judge
from app.integrations.vision.base import VisionVerdict

_QR_PREFIX = "colortrip:quest:"
_QR_SIGNATURE_LENGTH = 16


async def judge_photo(
    image_bytes: bytes, mime_type: str, title: str, place: str, conditions: list[str]
) -> VisionVerdict:
    """퀘스트 맥락(제목·장소·조건)으로 사진을 판정한다.

    호출자는 `app/quests/verification.py` 하나이며, 업로드로 **이미 저장된** 사진을 읽어
    넘긴다(KAN-73 — 판정 전용 엔드포인트를 없애고 인증 경로에 통합했다). 판정 맥락은
    서버가 가진 퀘스트 데이터로만 구성한다.
    """
    prompt = build_photo_judgement_prompt(title, place, conditions)
    judge = get_vision_judge()
    return await judge.judge(image_bytes, mime_type, prompt)


def _qr_secret() -> bytes:
    """QR 서명 키 — QR_SECRET_KEY 미설정 시 JWT_SECRET_KEY에서 파생한다."""
    secret = settings.qr_secret_key.strip()
    if secret:
        return secret.encode("utf-8")
    return hashlib.sha256(f"{settings.jwt_secret_key}:qr".encode()).digest()


def _sign(quest_id: str) -> str:
    message = f"{_QR_PREFIX}{quest_id}".encode()
    return hmac.new(_qr_secret(), message, hashlib.sha256).hexdigest()[:_QR_SIGNATURE_LENGTH]


def sign_quest_payload(quest_id: str) -> str:
    """퀘스트 현장 QR에 담을 서명 페이로드를 만든다 (scripts/generate_quest_qr.py에서 사용)."""
    return f"{_QR_PREFIX}{quest_id}:{_sign(quest_id)}"


def verify_qr_payload(payload: str, expected_quest_id: str) -> tuple[bool, str]:
    """QR 페이로드의 서명·대상 퀘스트를 검증한다. (통과 여부, 사유)를 반환한다.

    실패 사유는 형식 오류 / 서명 불일치(위·변조) / 다른 퀘스트의 QR로 구분한다.
    """
    stripped = payload.strip()
    if not stripped.startswith(_QR_PREFIX):
        return False, "ColorTrip 퀘스트 QR이 아니에요."

    quest_id, separator, signature = stripped[len(_QR_PREFIX) :].rpartition(":")
    if not separator or not quest_id or not signature:
        return False, "QR 형식이 올바르지 않아요."

    if not hmac.compare_digest(signature, _sign(quest_id)):
        return False, "위조되었거나 손상된 QR이에요."

    if quest_id != expected_quest_id:
        return False, "이 퀘스트의 QR이 아니에요."

    return True, "현장 QR이 확인되었어요."
