"""퀘스트 인증 판정 — 룰 기반 MVP.

규칙(docs/specs/010-journey/plan.md · docs/specs/050-quest-verification/):
- gps_photo: 퀘스트 좌표 기준 verify_radius(m) 이내 + 인증 사진 존재.
  사진 내용(LLM) 판정은 후속 — 프롬프트는 mission_meta["judgement_prompt"]에 보관만 한다.
- quiz: 제출 답안과 mission_meta["quiz"]["answer"]를 정규화(공백·대소문자) 비교.
- qr: 현장 QR 페이로드의 HMAC 서명 검증 (app/verifications/service.py 재사용).
"""

import math
from decimal import Decimal

from app.core.enums import MissionType
from app.core.exceptions import AppException, ErrorCode
from app.quests.models import Quest
from app.verifications.service import verify_qr_payload

_EARTH_RADIUS_M = 6_371_000


def haversine_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """두 좌표 사이 거리(m)."""
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lng2 - lng1)
    a = math.sin(d_phi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    return 2 * _EARTH_RADIUS_M * math.asin(math.sqrt(a))


def judge(
    quest: Quest,
    *,
    lat: Decimal | None,
    lng: Decimal | None,
    photo_url: str | None,
    answer: str | None,
    qr_payload: str | None = None,
) -> tuple[bool, str | None]:
    """미션 타입별 인증 판정. (성공 여부, 실패 사유)를 반환한다.

    판정에 필요한 입력이 없으면 VALIDATION_ERROR를 발생시킨다.
    """
    if quest.mission_type == MissionType.QUIZ.value:
        return _judge_quiz(quest, answer)
    if quest.mission_type == MissionType.QR.value:
        return _judge_qr(quest, qr_payload)
    return _judge_gps_photo(quest, lat, lng, photo_url)


def _judge_gps_photo(
    quest: Quest, lat: Decimal | None, lng: Decimal | None, photo_url: str | None
) -> tuple[bool, str | None]:
    if lat is None or lng is None or not photo_url:
        raise AppException(
            ErrorCode.VALIDATION_ERROR, "GPS 좌표(lat·lng)와 인증 사진이 필요합니다."
        )
    if quest.lat is None or quest.lng is None:
        raise AppException(ErrorCode.VALIDATION_ERROR, "퀘스트에 인증 기준 좌표가 없습니다.")

    distance = haversine_m(float(lat), float(lng), float(quest.lat), float(quest.lng))
    if distance > quest.verify_radius:
        return False, f"인증 반경({quest.verify_radius}m)을 벗어났습니다 (현재 {int(distance)}m)."
    return True, None


def _judge_qr(quest: Quest, qr_payload: str | None) -> tuple[bool, str | None]:
    if qr_payload is None or not qr_payload.strip():
        raise AppException(ErrorCode.VALIDATION_ERROR, "QR 페이로드(qr_payload)가 필요합니다.")

    passed, reason = verify_qr_payload(qr_payload, str(quest.id))
    return passed, None if passed else reason  # 성공 사유는 버린다(실패 사유만 반환하는 규약)


def _judge_quiz(quest: Quest, answer: str | None) -> tuple[bool, str | None]:
    if answer is None or not answer.strip():
        raise AppException(ErrorCode.VALIDATION_ERROR, "퀴즈 답안(answer)이 필요합니다.")

    meta = quest.mission_meta or {}
    expected = (meta.get("quiz") or {}).get("answer")
    if not isinstance(expected, str) or not expected.strip():
        raise AppException(
            ErrorCode.VALIDATION_ERROR, "퀘스트에 퀴즈 정답이 등록되어 있지 않습니다."
        )

    if _normalize(answer) != _normalize(expected):
        return False, "정답이 아닙니다."
    return True, None


def _normalize(value: str) -> str:
    return "".join(value.split()).lower()
