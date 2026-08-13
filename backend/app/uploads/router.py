"""uploads — 인증 사진 업로드 라우터 (VRF-03). 보호 API."""

from fastapi import APIRouter, Depends, UploadFile
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import CurrentUser
from app.core.database import get_session
from app.core.response import Envelope, success
from app.uploads import service
from app.uploads.models import UploadedPhoto
from app.uploads.storage import PhotoStorage, get_photo_storage

router = APIRouter(prefix="/uploads", tags=["uploads"])


class PhotoUploadData(BaseModel):
    photo_url: str


@router.post("/photo", status_code=201)
async def upload_photo(
    file: UploadFile,
    current_user: CurrentUser,
    session: AsyncSession = Depends(get_session),
    storage: PhotoStorage = Depends(get_photo_storage),
) -> Envelope[PhotoUploadData]:
    image = await service.store_uploaded_image(file, storage, prefix="photos")
    session.add(UploadedPhoto(user_id=current_user.id, photo_url=image.url))

    async def is_persisted(check_session: AsyncSession) -> bool:
        found = await check_session.scalar(
            select(UploadedPhoto.id).where(UploadedPhoto.photo_url == image.url)
        )
        return found is not None

    await service.commit_or_discard_image(session, storage, image, is_persisted=is_persisted)
    return success(
        PhotoUploadData(photo_url=image.url), status=201, message="사진을 업로드했습니다."
    )
