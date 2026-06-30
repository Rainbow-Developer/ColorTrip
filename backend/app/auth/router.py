"""auth — API routers."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import service
from app.auth.dependencies import CurrentUser
from app.auth.kakao import KakaoClient, get_kakao_client
from app.auth.schemas import (
    AuthTokenData,
    AuthTokenRequest,
    LogoutRequest,
    RefreshTokenRenewalData,
    RefreshTokenRenewalRequest,
    UserProfile,
)
from app.core.database import get_session
from app.core.response import Envelope, success

auth_router = APIRouter(prefix="/auth", tags=["auth"])
users_router = APIRouter(prefix="/users", tags=["users"])


@auth_router.post("/login/social")
async def create_auth_token(
    payload: AuthTokenRequest,
    session: AsyncSession = Depends(get_session),
    kakao_client: KakaoClient = Depends(get_kakao_client),
) -> Envelope[AuthTokenData]:
    if payload.access_token is not None:
        data = await service.login_with_kakao_access_token(
            session,
            kakao_access_token=payload.access_token,
            kakao_client=kakao_client,
        )
    else:
        data = await service.login_with_kakao_authorization_code(
            session,
            authorization_code=payload.authorization_code or "",
            kakao_client=kakao_client,
        )
    return success(data)


@auth_router.post("/refresh")
async def renew_auth_token(
    payload: RefreshTokenRenewalRequest,
    session: AsyncSession = Depends(get_session),
) -> Envelope[RefreshTokenRenewalData]:
    data = await service.renew_refresh_token(session, refresh_token=payload.refresh_token)
    return success(data)


@auth_router.post("/logout")
async def delete_current_auth_token(
    payload: LogoutRequest,
    current_user: CurrentUser,
    session: AsyncSession = Depends(get_session),
) -> Envelope[None]:
    await service.logout(
        session,
        refresh_token=payload.refresh_token,
        current_user=current_user,
    )
    return success(None)


@users_router.get("/me")
async def get_my_profile(current_user: CurrentUser) -> Envelope[UserProfile]:
    return success(UserProfile.model_validate(current_user))


@users_router.delete("/me")
async def delete_my_profile(
    current_user: CurrentUser,
    session: AsyncSession = Depends(get_session),
) -> Envelope[None]:
    await service.withdraw_current_user(session, current_user=current_user)
    return success(None)
