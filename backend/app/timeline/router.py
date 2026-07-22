from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import CurrentUser
from app.core.database import get_session
from app.core.response import Envelope, success
from app.timeline import service
from app.timeline.schemas import TimelineRead

router = APIRouter(prefix="/users/me/timeline", tags=["timeline"])


@router.get("", response_model=Envelope[list[TimelineRead]])
async def get_my_timeline(
    current_user: CurrentUser,
    year: int | None = Query(None, description="조회할 연도"),
    month: int | None = Query(None, ge=1, le=12, description="조회할 월(1~12)"),
    session: AsyncSession = Depends(get_session),
) -> Envelope[list[TimelineRead]]:
    """인증된 사용자의 여행 발자취 타임라인을 조회합니다."""
    items = await service.get_user_timeline(
        session, user_id=current_user.id, year=year, month=month
    )
    return success(items)