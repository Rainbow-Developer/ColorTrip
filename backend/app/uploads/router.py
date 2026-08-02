"""uploads — 인증 사진 업로드 라우터 (VRF-03). 보호 API."""

import logging

from fastapi import APIRouter, Depends, UploadFile
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import CurrentUser
from app.core.base import new_uuid7, now_kst
from app.core.config import settings
from app.core.database import get_session
from app.core.exceptions import AppException, ErrorCode
from app.core.response import Envelope, success
from app.uploads.models import UploadedPhoto
from app.uploads.storage import PhotoStorage, get_photo_storage

router = APIRouter(prefix="/uploads", tags=["uploads"])
logger = logging.getLogger(__name__)

_ALLOWED_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/heic": ".heic",
}


class PhotoUploadData(BaseModel):
    photo_url: str


@router.post("/photo", status_code=201)
async def upload_photo(
    file: UploadFile,
    current_user: CurrentUser,
    session: AsyncSession = Depends(get_session),
    storage: PhotoStorage = Depends(get_photo_storage),
) -> Envelope[PhotoUploadData]:
    content_type = (file.content_type or "").lower()
    extension = _ALLOWED_TYPES.get(content_type)
    if extension is None:
        raise AppException(
            ErrorCode.VALIDATION_ERROR,
            f"지원하지 않는 이미지 형식입니다: {content_type or '알 수 없음'}",
        )

    max_bytes = settings.max_upload_size_mb * 1024 * 1024
    # 전체를 읽어 버퍼링하기 전에, 파서가 계산한 크기로 초과 업로드를 먼저 차단한다.
    if file.size is not None and file.size > max_bytes:
        raise AppException(
            ErrorCode.VALIDATION_ERROR,
            f"파일이 너무 큽니다 (최대 {settings.max_upload_size_mb}MB).",
        )

    content = await file.read()
    if not content:
        raise AppException(ErrorCode.VALIDATION_ERROR, "빈 파일은 업로드할 수 없습니다.")
    if len(content) > max_bytes:  # size가 None인 경우의 안전망
        raise AppException(
            ErrorCode.VALIDATION_ERROR,
            f"파일이 너무 큽니다 (최대 {settings.max_upload_size_mb}MB).",
        )

    object_name = f"photos/{now_kst():%Y/%m}/{new_uuid7().hex}{extension}"
    photo_url = await storage.save(object_name, content, content_type)
    session.add(UploadedPhoto(user_id=current_user.id, photo_url=photo_url))
    try:
        await session.commit()
    except Exception:
        await session.rollback()
        try:
            await storage.delete(object_name)
        except Exception:
            logger.exception("업로드 DB 저장 실패 후 스토리지 정리 실패: %s", object_name)
        logger.exception("업로드 DB 저장 실패로 스토리지 객체를 정리했습니다: %s", object_name)
        raise
    return success(
        PhotoUploadData(photo_url=photo_url), status=201, message="사진을 업로드했습니다."
    )
