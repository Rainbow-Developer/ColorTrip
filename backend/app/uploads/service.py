"""업로드 이미지 저장 공용 로직과 인증 사진의 소유권 검증.

이미지 검증·저장·보상 삭제는 퀘스트 인증 사진(`/uploads/photo`)과 프로필 이미지
(`/users/me/profile-image`)가 함께 쓴다. 두 곳에 복사하면 검증 순서나 보상 삭제
조건이 한쪽만 바뀌는 드리프트가 생기므로 여기로 모은다 (080-profile-image 의사결정 6).
"""

import logging
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from uuid import UUID

from fastapi import UploadFile
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.base import new_uuid7, now_kst
from app.core.config import settings
from app.core.database import AsyncSessionLocal
from app.core.exceptions import AppException, ErrorCode
from app.uploads.models import UploadedPhoto
from app.uploads.storage import PhotoStorage

logger = logging.getLogger(__name__)

ALLOWED_IMAGE_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/heic": ".heic",
}


@dataclass(frozen=True)
class StoredImage:
    """스토리지에 저장된 이미지. `object_name`은 보상 삭제에, `url`은 응답·DB에 쓴다."""

    object_name: str
    url: str


async def store_uploaded_image(
    file: UploadFile,
    storage: PhotoStorage,
    *,
    prefix: str,
) -> StoredImage:
    """업로드 파일을 검증하고 `{prefix}/{YYYY}/{MM}/{uuid7}{ext}`로 저장한다.

    호출자는 저장 후 DB 반영까지 마쳐야 하며, commit 실패 시
    `commit_or_discard_image`로 저장된 객체를 정리해야 한다.
    """
    content_type = (file.content_type or "").lower()
    extension = ALLOWED_IMAGE_TYPES.get(content_type)
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

    object_name = f"{prefix}/{now_kst():%Y/%m}/{new_uuid7().hex}{extension}"
    url = await storage.save(object_name, content, content_type)
    return StoredImage(object_name=object_name, url=url)


async def commit_or_discard_image(
    session: AsyncSession,
    storage: PhotoStorage,
    image: StoredImage,
    *,
    is_persisted: Callable[[AsyncSession], Awaitable[bool]],
) -> None:
    """세션을 commit하고, 실패하면 저장된 스토리지 객체를 보상 삭제한다.

    commit 응답만 실패하고 실제로는 저장됐을 수 있으므로, 지우기 전에 별도 세션으로
    `is_persisted`를 다시 확인한다. 저장돼 있으면 객체를 지우지 않는다.
    """
    try:
        await session.commit()
    except Exception:
        await session.rollback()
        async with AsyncSessionLocal() as check_session:
            persisted = await is_persisted(check_session)
        if persisted:
            logger.exception("업로드 커밋 응답 실패지만 레코드는 저장됨: %s", image.object_name)
        else:
            try:
                await storage.delete(image.object_name)
            except Exception:
                logger.exception("업로드 DB 저장 실패 후 스토리지 정리 실패: %s", image.object_name)
            else:
                logger.exception(
                    "업로드 DB 저장 실패로 스토리지 객체를 정리했습니다: %s", image.object_name
                )
        raise


async def require_owned_photo(session: AsyncSession, user_id: UUID, photo_url: str | None) -> None:
    if not photo_url:
        raise AppException(ErrorCode.VALIDATION_ERROR, "업로드한 인증 사진이 필요합니다.")
    owned = await session.scalar(
        select(UploadedPhoto.id).where(
            UploadedPhoto.user_id == user_id,
            UploadedPhoto.photo_url == photo_url,
            UploadedPhoto.deleted_at.is_(None),
        )
    )
    if owned is None:
        raise AppException(ErrorCode.VALIDATION_ERROR, "본인이 업로드한 인증 사진이 필요합니다.")
