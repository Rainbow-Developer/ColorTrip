"""인증 사진의 업로드 소유권 검증."""

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AppException, ErrorCode
from app.uploads.models import UploadedPhoto


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
