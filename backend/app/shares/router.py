from __future__ import annotations

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import CurrentUser
from app.core.database import get_session
from app.core.response import Envelope, success
from app.shares import service
from app.shares.schemas import (
    ShareCreateRequest,
    ShareCreateResponse,
    ShareReadResponse,
    ShareSummaryResponse,
)

router = APIRouter(tags=["shares"])


@router.get("/users/me/share-summary", response_model=Envelope[ShareSummaryResponse])
async def get_my_share_summary(
    current_user: CurrentUser,
    session: AsyncSession = Depends(get_session),
) -> Envelope[ShareSummaryResponse]:
    """내 여행 지도 진행률, DNA, 색칠된 시·군 목록 요약 데이터를 조회합니다."""
    summary = await service.get_user_share_summary_data(session, current_user)
    return success(summary)


@router.post(
    "/shares",
    response_model=Envelope[ShareCreateResponse],
    status_code=status.HTTP_201_CREATED,
)
async def create_share_card(
    payload: ShareCreateRequest,
    current_user: CurrentUser,
    session: AsyncSession = Depends(get_session),
) -> Envelope[ShareCreateResponse]:
    """선택한 공유 스타일에 따른 숏코드 및 공유 URL을 생성합니다."""
    res = await service.create_share_card(session, current_user, payload)
    return success(res)


@router.get("/shares/{share_code}", response_model=Envelope[ShareReadResponse])
async def get_public_share_card(
    share_code: str,
    session: AsyncSession = Depends(get_session),
) -> Envelope[ShareReadResponse]:
    """외부 누구나 접속 가능한 공개 공유 카드 데이터를 조회합니다."""
    card_data = await service.get_public_share_card(session, share_code)
    return success(card_data)
