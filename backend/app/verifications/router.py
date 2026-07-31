"""스테이트리스 퀘스트 인증 라우터 — docs/specs/050-quest-verification/

프론트 정적 카탈로그용이라 DB 퀘스트를 참조하지 않는다. 보호 API.
- POST /verifications/photo: 사진 + 퀘스트 맥락 → 비전 판정 (사진 비저장)
- POST /verifications/qr: 스캔 페이로드 → HMAC 서명 검증
"""

from typing import Annotated

from fastapi import APIRouter, Form, UploadFile

from app.auth.dependencies import CurrentUser
from app.core.config import settings
from app.core.exceptions import AppException, ErrorCode
from app.core.response import Envelope, success
from app.verifications import service
from app.verifications.schemas import PhotoVerifyData, QrVerifyData, QrVerifyRequest

router = APIRouter(prefix="/verifications", tags=["verifications"])


@router.post("/photo")
async def verify_photo(
    image: UploadFile,
    current_user: CurrentUser,
    title: Annotated[str, Form()],
    place: Annotated[str, Form()],
    conditions: Annotated[str, Form()] = "",  # 줄바꿈으로 구분한 인증 조건 목록
) -> Envelope[PhotoVerifyData]:
    content_type = (image.content_type or "").lower()
    if not content_type.startswith("image/"):
        raise AppException(
            ErrorCode.VALIDATION_ERROR,
            f"이미지 파일만 판정할 수 있습니다: {content_type or '알 수 없음'}",
        )

    max_bytes = settings.max_upload_size_mb * 1024 * 1024
    # 전체를 읽어 버퍼링하기 전에, 파서가 계산한 크기로 초과 업로드를 먼저 차단한다.
    if image.size is not None and image.size > max_bytes:
        raise AppException(
            ErrorCode.VALIDATION_ERROR,
            f"파일이 너무 큽니다 (최대 {settings.max_upload_size_mb}MB).",
        )

    content = await image.read()
    if not content:
        raise AppException(ErrorCode.VALIDATION_ERROR, "빈 파일은 판정할 수 없습니다.")
    if len(content) > max_bytes:  # size가 None인 경우의 안전망
        raise AppException(
            ErrorCode.VALIDATION_ERROR,
            f"파일이 너무 큽니다 (최대 {settings.max_upload_size_mb}MB).",
        )

    verdict = await service.judge_photo(
        content,
        content_type,
        title=title,
        place=place,
        conditions=[line.strip() for line in conditions.splitlines() if line.strip()],
    )
    return success(
        PhotoVerifyData(
            passed=verdict.passed,
            confidence=verdict.confidence,
            reason=verdict.reason,
            provider=verdict.provider,
        ),
        message="사진 판정이 완료되었습니다.",
    )


@router.post("/qr")
async def verify_qr(body: QrVerifyRequest, current_user: CurrentUser) -> Envelope[QrVerifyData]:
    passed, reason = service.verify_qr_payload(body.payload, body.quest_id)
    return success(QrVerifyData(passed=passed, reason=reason), message="QR 검증이 완료되었습니다.")
