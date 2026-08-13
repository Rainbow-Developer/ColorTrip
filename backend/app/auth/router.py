"""auth — API routers."""

from fastapi import APIRouter, Depends, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import service
from app.auth.dependencies import ActiveUser, CurrentUser
from app.auth.kakao import KakaoClient, get_kakao_client
from app.auth.schemas import (
    AuthTokenData,
    AuthTokenRequest,
    LogoutRequest,
    OnboardingProfileRequest,
    RefreshTokenRenewalData,
    RefreshTokenRenewalRequest,
    UserProfile,
    UserProfileUpdateRequest,
)
from app.core.database import get_session
from app.core.response import Envelope, success
from app.uploads.storage import PhotoStorage, get_photo_storage

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
    current_user: ActiveUser,
    session: AsyncSession = Depends(get_session),
) -> Envelope[None]:
    await service.logout(
        session,
        refresh_token=payload.refresh_token,
        current_user=current_user,
    )
    return success(None)


@users_router.get("/me")
async def get_my_profile(
    current_user: ActiveUser,
    session: AsyncSession = Depends(get_session),
) -> Envelope[UserProfile]:
    return success(await service.build_user_profile(session, current_user))


@users_router.put("/me/onboarding-profile")
async def put_my_onboarding_profile(
    payload: OnboardingProfileRequest,
    current_user: ActiveUser,
    session: AsyncSession = Depends(get_session),
) -> Envelope[UserProfile]:
    data = await service.save_onboarding_profile(
        session,
        current_user=current_user,
        payload=payload,
    )
    return success(data)


@users_router.patch("/me")
async def patch_my_profile(
    payload: UserProfileUpdateRequest,
    current_user: CurrentUser,
    session: AsyncSession = Depends(get_session),
) -> Envelope[UserProfile]:
    data = await service.update_current_user_profile(
        session,
        current_user=current_user,
        payload=payload,
    )
    return success(data)


@users_router.post("/me/profile-image")
async def post_my_profile_image(
    file: UploadFile,
    current_user: ActiveUser,
    session: AsyncSession = Depends(get_session),
    storage: PhotoStorage = Depends(get_photo_storage),
) -> Envelope[UserProfile]:
    data = await service.replace_profile_image(
        session,
        current_user=current_user,
        file=file,
        storage=storage,
    )
    return success(data, message="프로필 이미지를 저장했습니다.")


@users_router.delete("/me/profile-image")
async def delete_my_profile_image(
    current_user: ActiveUser,
    session: AsyncSession = Depends(get_session),
) -> Envelope[UserProfile]:
    data = await service.remove_profile_image(session, current_user=current_user)
    return success(data, message="프로필 이미지를 삭제했습니다.")


@users_router.delete("/me")
async def delete_my_profile(
    current_user: ActiveUser,
    session: AsyncSession = Depends(get_session),
) -> Envelope[None]:
    await service.withdraw_current_user(session, current_user=current_user)
    return success(None)
