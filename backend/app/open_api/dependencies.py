"""오픈 API 서비스키 인증 — 사용자 로그인(JWT)과는 별개의 기관 대 기관 인증 축이다."""

from typing import Annotated

from fastapi import Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.core.exceptions import AppException, ErrorCode
from app.core.security import hash_open_api_key
from app.open_api.models import OpenApiKey


async def get_active_open_api_key(
    serviceKey: str | None = Query(default=None),
    session: AsyncSession = Depends(get_session),
) -> OpenApiKey:
    if not serviceKey:
        raise AppException(ErrorCode.UNAUTHORIZED_ERROR, "serviceKey가 필요합니다.")

    key_hash = hash_open_api_key(serviceKey)
    stmt = select(OpenApiKey).where(
        OpenApiKey.key_hash == key_hash,
        OpenApiKey.is_active.is_(True),
        OpenApiKey.deleted_at.is_(None),
    )
    result = await session.execute(stmt)
    key = result.scalar_one_or_none()
    if key is None:
        raise AppException(ErrorCode.UNAUTHORIZED_ERROR, "유효하지 않은 serviceKey입니다.")
    return key


type ActiveOpenApiKey = Annotated[OpenApiKey, Depends(get_active_open_api_key)]
