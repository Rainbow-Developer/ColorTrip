"""퀘스트 인증 판정.

규칙(docs/specs/010-journey/plan.md · docs/specs/050-quest-verification/):
- photo: 업로드한 인증 사진을 **스토리지에서 읽어 비전 모델로 판정**한다.
- gps: **단말이** 반경 판정을 끝내고 서버는 완료만 기록한다. 좌표를 보내면 거절한다
  (좌표 비전송 — location-law-review.md의 B안. 수신만 해도 신고 대상이 된다).
- gps_photo: 좌표 반경 이내 + 사진 비전 판정 통과 (FE 미사용 — 쓰려면 신고가 선행).
- quiz: 제출 답안과 mission_meta["quiz"]["answer"]를 정규화(공백·대소문자) 비교.
- qr: 현장 QR 페이로드의 HMAC 서명 검증 (app/verifications/service.py 재사용).
  대조 기준은 client_key다 — 인쇄한 QR이 DB 재시딩(UUID 변경)에도 살아있어야 한다.

사진은 업로드(`POST /uploads/photo`) 때 한 번만 전송하고, 판정은 저장본을 읽어 수행한다
(KAN-73 — 이전에는 판정 전용 API로 같은 사진을 한 번 더 보냈다). 사진을 읽지 못하거나
URL 형태가 스토리지 규약과 다르면 **거절**한다(fail-closed — 판정 없이 통과시키지 않는다).

판정 입력은 [QuestJudgeInput] 값 스냅샷으로 받는다 — 비전 판정(외부 API, 최대 30초) 동안
DB 커넥션을 붙잡지 않으려면 호출자가 트랜잭션을 닫아야 하고, 그러면 ORM 객체는 expire되어
async에서 속성 접근이 실패한다(`MissingGreenlet`).
"""

import logging
import math
from dataclasses import dataclass
from decimal import Decimal
from typing import Any

from app.core.config import settings
from app.core.enums import MissionType
from app.core.exceptions import AppException, ErrorCode
from app.integrations.vision.base import VisionVerdict
from app.quests.models import Quest
from app.uploads.storage import get_photo_storage, object_name_from_url
from app.verifications.service import judge_photo, verify_qr_payload

logger = logging.getLogger(__name__)

_EARTH_RADIUS_M = 6_371_000


def haversine_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """두 좌표 사이 거리(m)."""
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lng2 - lng1)
    a = math.sin(d_phi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    return 2 * _EARTH_RADIUS_M * math.asin(math.sqrt(a))


@dataclass(frozen=True)
class QuestJudgeInput:
    """판정에 필요한 퀘스트 값 — ORM 객체와 분리해 세션 수명에 묶이지 않게 한다."""

    quest_id: str
    client_key: str | None
    mission_type: str
    title: str
    description: str | None
    mission_meta: dict[str, Any] | None
    lat: Decimal | None
    lng: Decimal | None
    verify_radius: int

    @property
    def needs_external_judgement(self) -> bool:
        """비전 모델 호출(느린 외부 API)이 필요한 미션인지 — 호출자가 트랜잭션 종료를 판단."""
        return self.mission_type in {MissionType.PHOTO.value, MissionType.GPS_PHOTO.value}


def snapshot(quest: Quest) -> QuestJudgeInput:
    """판정 입력을 ORM 객체에서 값으로 복사한다(세션을 닫기 전에 호출해야 한다)."""
    return QuestJudgeInput(
        quest_id=str(quest.id),
        client_key=quest.client_key,
        mission_type=quest.mission_type,
        title=quest.title,
        description=quest.description,
        mission_meta=quest.mission_meta,
        lat=quest.lat,
        lng=quest.lng,
        verify_radius=quest.verify_radius,
    )


class JudgeOutcome:
    """인증 판정 결과 — 성공 여부, 실패 사유, (사진 미션이면) 비전 판정 상세."""

    __slots__ = ("passed", "photo_verdict", "reason")

    def __init__(
        self,
        passed: bool,
        reason: str | None = None,
        photo_verdict: VisionVerdict | None = None,
    ) -> None:
        self.passed = passed
        self.reason = reason
        self.photo_verdict = photo_verdict


async def judge(
    quest: QuestJudgeInput,
    *,
    lat: Decimal | None,
    lng: Decimal | None,
    photo_url: str | None,
    answer: str | None,
    qr_payload: str | None = None,
) -> JudgeOutcome:
    """미션 타입별 인증 판정.

    판정에 필요한 입력이 없으면 VALIDATION_ERROR를 발생시킨다.
    """
    if quest.mission_type == MissionType.QUIZ.value:
        return _outcome(_judge_quiz(quest, answer))
    if quest.mission_type == MissionType.QR.value:
        return _outcome(_judge_qr(quest, qr_payload))
    if quest.mission_type == MissionType.PHOTO.value:
        _require_uploaded_photo(photo_url)
        return await _judge_photo(quest, photo_url)
    if quest.mission_type == MissionType.GPS.value:
        return _outcome(_judge_gps_on_device(lat, lng))
    if quest.mission_type == MissionType.GPS_PHOTO.value:
        _require_uploaded_photo(photo_url)
        gps_passed, gps_reason = _judge_gps(quest, lat, lng)
        if not gps_passed:
            return JudgeOutcome(False, gps_reason)  # 반경을 벗어나면 판정 비용을 쓰지 않는다
        return await _judge_photo(quest, photo_url)
    raise AppException(ErrorCode.VALIDATION_ERROR, "지원하지 않는 미션 유형입니다.")


def _outcome(result: tuple[bool, str | None]) -> JudgeOutcome:
    passed, reason = result
    return JudgeOutcome(passed, reason)


async def _judge_photo(quest: QuestJudgeInput, photo_url: str | None) -> JudgeOutcome:
    """업로드된 사진을 스토리지에서 읽어 비전 판정한다 (읽기 실패 시 거절)."""
    object_name = object_name_from_url(photo_url or "")
    if object_name is None:
        return JudgeOutcome(False, "인증 사진을 찾을 수 없습니다. 다시 업로드해주세요.")

    storage = get_photo_storage()  # 초기화 오류는 삼키지 않는다(설정 문제 → 500으로 드러냄)
    try:
        image_bytes = await storage.load(object_name)
    except Exception:  # 파일 없음·스토리지 오류 — 판정 없이 통과시키지 않는다
        # 조용히 거절하면 스토리지 장애(자격증명 만료 등)를 감지할 수 없다.
        logger.exception("인증 사진 로드 실패 — 판정 없이 거절합니다 (object=%s)", object_name)
        return JudgeOutcome(False, "인증 사진을 불러오지 못했습니다. 다시 시도해주세요.")

    verdict = await judge_photo(
        image_bytes,
        _mime_type_for(object_name),
        quest.title,
        "",  # 서버 퀘스트에는 장소명 컬럼이 없다 — 설명을 조건 맥락으로 넘긴다
        _conditions_of(quest),
    )
    return JudgeOutcome(
        verdict.passed,
        None if verdict.passed else verdict.reason,
        photo_verdict=verdict,
    )


def _mime_type_for(object_name: str) -> str:
    extension = object_name.rsplit(".", 1)[-1].lower()
    return {
        "png": "image/png",
        "webp": "image/webp",
        "heic": "image/heic",
    }.get(extension, "image/jpeg")


def _conditions_of(quest: QuestJudgeInput) -> list[str]:
    """판정 프롬프트에 넣을 조건 — **서버가 가진 데이터만** 쓴다.

    클라이언트가 판정 맥락을 보내던 이전 방식(`POST /verifications/photo`)에서는 조건을
    느슨하게 바꿔 통과를 유도할 수 있었다. 이제 mission_meta(판정 프롬프트·조건 목록)와
    설명만 사용한다.
    """
    meta = quest.mission_meta or {}
    conditions = meta.get("conditions")
    if isinstance(conditions, list) and conditions:
        return [str(item) for item in conditions]

    prompt = meta.get("judgement_prompt")
    if isinstance(prompt, str) and prompt.strip():
        return [prompt.strip()]

    description = (quest.description or "").strip()
    return [description] if description else []


def _judge_gps_on_device(
    lat: Decimal | None,
    lng: Decimal | None,
) -> tuple[bool, str | None]:
    """gps 미션 — 거리 판정은 **단말이** 끝냈고 서버는 완료만 기록한다 (KAN-77).

    좌표는 받지 않는다. 저장하지 않더라도 **수신하는 것만으로** 위치정보법상
    위치기반서비스사업 신고 대상이 되기 때문이다(팀 결정 B안 —
    docs/specs/050-quest-verification/location-law-review.md). 그래서 좌표가 오면
    무시가 아니라 **거절**한다 — 무시하면 클라이언트가 계속 보내도 아무도 모른 채
    신고 대상 상태가 유지된다.

    대가로 이 미션은 클라이언트 변조에 취약하다(위 문서의 B안 트레이드오프로 수용).
    서버 검증이 필요해지는 시점 = 신고 시점이며, 그때 gps_photo의 `_judge_gps`
    경로를 쓰면 된다.
    """
    if lat is not None or lng is not None:
        raise AppException(
            ErrorCode.VALIDATION_ERROR,
            "위치 인증은 단말에서 판정합니다. 좌표(lat·lng)를 보내지 마세요.",
        )
    return True, None


def _judge_gps(
    quest: QuestJudgeInput,
    lat: Decimal | None,
    lng: Decimal | None,
) -> tuple[bool, str | None]:
    """좌표 기반 서버 검증 — **gps_photo 전용**이며 FE는 사용하지 않는다.

    이 경로를 쓰기 시작하는 순간 좌표를 수신하게 되므로 위치기반서비스사업 신고가
    선행되어야 한다(location-law-review.md의 A안 전환 절차).
    """
    if lat is None or lng is None:
        raise AppException(ErrorCode.VALIDATION_ERROR, "GPS 좌표(lat·lng)가 필요합니다.")
    if quest.lat is None or quest.lng is None:
        raise AppException(ErrorCode.VALIDATION_ERROR, "퀘스트에 인증 기준 좌표가 없습니다.")

    distance = haversine_m(float(lat), float(lng), float(quest.lat), float(quest.lng))
    if distance > quest.verify_radius:
        return False, f"인증 반경({quest.verify_radius}m)을 벗어났습니다 (현재 {int(distance)}m)."
    return True, None


def _judge_qr(quest: QuestJudgeInput, qr_payload: str | None) -> tuple[bool, str | None]:
    """현장 QR 서명을 검증한다 — 대조 기준은 **client_key**다(KAN-75).

    이전에는 DB의 UUID(`quest.quest_id`)와 대조했는데, QR을 만드는
    `scripts/generate_quest_qr.py`는 client_key(`dy3` 등)로 서명하므로 서명이 유효해도
    항상 "이 퀘스트의 QR이 아니에요"로 떨어졌다. client_key는 FE 정적 데이터와 공유하는
    안정적인 식별자라, 퀘스트 행을 재시딩해 UUID가 바뀌어도 인쇄한 QR이 계속 유효하다.
    """
    if qr_payload is None or not qr_payload.strip():
        raise AppException(ErrorCode.VALIDATION_ERROR, "QR 페이로드(qr_payload)가 필요합니다.")
    if not quest.client_key:
        # client_key 없이 QR 미션을 등록한 데이터 오류 — 통과시키지 않는다(fail-closed).
        logger.error("QR 퀘스트에 client_key가 없습니다 (quest=%s)", quest.quest_id)
        return False, "이 퀘스트의 QR 인증 정보가 준비되지 않았어요."

    passed, reason = verify_qr_payload(qr_payload, quest.client_key)
    return passed, None if passed else reason  # 성공 사유는 버린다(실패 사유만 반환하는 규약)


def _require_uploaded_photo(photo_url: str | None) -> None:
    if not photo_url or ".." in photo_url:
        raise AppException(ErrorCode.VALIDATION_ERROR, "업로드한 인증 사진이 필요합니다.")

    local_photo = photo_url.startswith("/uploads/photos/")
    gcs_prefix = (
        f"https://storage.googleapis.com/{settings.gcs_upload_bucket}/photos/"
        if settings.gcs_upload_bucket
        else None
    )
    if not local_photo and (gcs_prefix is None or not photo_url.startswith(gcs_prefix)):
        raise AppException(ErrorCode.VALIDATION_ERROR, "허용되지 않은 인증 사진 경로입니다.")


def _judge_quiz(quest: QuestJudgeInput, answer: str | None) -> tuple[bool, str | None]:
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
