"""auth — business logic."""

from datetime import date, datetime, timedelta
from uuid import UUID

from fastapi import UploadFile
from sqlalchemy import delete, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import repository
from app.auth.kakao import KakaoClient, KakaoUserInfo
from app.auth.models import RefreshToken, User
from app.auth.schemas import (
    AuthTokenData,
    OnboardingProfileRequest,
    RefreshTokenRenewalData,
    UserProfile,
    UserProfileUpdateRequest,
)
from app.core.base import now_kst
from app.core.config import settings
from app.core.exceptions import AppException, ErrorCode
from app.core.security import create_access_token, create_refresh_token, hash_refresh_token
from app.legal.documents import PRIVACY, TERMS
from app.quests.models import QuestProgress
from app.uploads import service as uploads_service
from app.uploads.models import UploadedPhoto
from app.uploads.storage import PhotoStorage

TERMS_CONSENT_VERSION = TERMS.version
PRIVACY_CONSENT_VERSION = PRIVACY.version


def is_at_least_fourteen(birth_date: date, *, today: date | None = None) -> bool:
    current = today or now_kst().date()
    try:
        fourteenth_birthday = birth_date.replace(year=birth_date.year + 14)
    except ValueError:
        fourteenth_birthday = birth_date.replace(year=birth_date.year + 14, day=28)
    return fourteenth_birthday <= current


async def login_with_kakao_access_token(
    session: AsyncSession,
    *,
    kakao_access_token: str,
    kakao_client: KakaoClient,
) -> AuthTokenData:
    await kakao_client.validate_access_token(kakao_access_token)
    kakao_user = await kakao_client.get_user_info(kakao_access_token)
    last_error: IntegrityError | None = None

    for _ in range(2):
        try:
            user, is_restored = await _sync_kakao_user(session, kakao_user)
            token_data = _issue_tokens(session, user)
            await session.commit()
            await session.refresh(user)
            token_data.user = await build_user_profile(session, user)
            token_data.is_restored = is_restored
            return token_data
        except IntegrityError as exc:
            last_error = exc
            await session.rollback()

    raise AppException(ErrorCode.INTERNAL_ERROR, "User login failed.") from last_error


async def login_with_kakao_authorization_code(
    session: AsyncSession,
    *,
    authorization_code: str,
    kakao_client: KakaoClient,
) -> AuthTokenData:
    access_token = await kakao_client.exchange_authorization_code(authorization_code)
    return await login_with_kakao_access_token(
        session,
        kakao_access_token=access_token,
        kakao_client=kakao_client,
    )


async def renew_refresh_token(
    session: AsyncSession,
    *,
    refresh_token: str,
) -> RefreshTokenRenewalData:
    token_hash = hash_refresh_token(refresh_token)
    token_row = await repository.get_refresh_token_by_hash_for_update(session, token_hash)
    if token_row is None:
        raise AppException(ErrorCode.UNAUTHORIZED_ERROR, "Refresh token is invalid.")

    now = now_kst()
    if token_row.deleted_at is not None:
        await repository.revoke_active_refresh_tokens(
            session,
            user_id=token_row.user_id,
            deleted_at=now,
        )
        await session.commit()
        raise AppException(ErrorCode.UNAUTHORIZED_ERROR, "Refresh token was already used.")

    user = await repository.get_active_user(session, token_row.user_id)
    if user is None:
        token_row.deleted_at = now
        await session.commit()
        raise AppException(ErrorCode.UNAUTHORIZED_ERROR, "Refresh token is invalid.")

    if _as_kst(token_row.expires_at) <= now:
        token_row.deleted_at = now
        await session.commit()
        raise AppException(ErrorCode.TOKEN_EXPIRED_ERROR, "Refresh token has expired.")

    token_row.deleted_at = now
    new_refresh_token = create_refresh_token()
    session.add(
        RefreshToken(
            user_id=user.id,
            token_hash=hash_refresh_token(new_refresh_token),
            expires_at=now + timedelta(days=settings.refresh_token_ttl_days),
        )
    )
    access_token = create_access_token(user_id=user.id)
    await session.commit()
    return RefreshTokenRenewalData(access_token=access_token, refresh_token=new_refresh_token)


async def logout(
    session: AsyncSession,
    *,
    refresh_token: str,
    current_user: User,
) -> None:
    token_hash = hash_refresh_token(refresh_token)
    token_row = await repository.get_refresh_token_by_hash_for_update(session, token_hash)
    if (
        token_row is None
        or token_row.user_id != current_user.id
        or token_row.deleted_at is not None
    ):
        raise AppException(ErrorCode.UNAUTHORIZED_ERROR, "Refresh token is invalid.")
    token_row.deleted_at = now_kst()
    await session.commit()


async def withdraw_current_user(
    session: AsyncSession,
    *,
    current_user: User,
    storage: PhotoStorage,
) -> None:
    current_user = await require_active_user_for_update(session, current_user.id)
    now = now_kst()
    # 익명화가 컬럼을 비우기 전에 잡아둔다 — 이후에는 URL을 알 수 없다.
    profile_image_url = current_user.profile_image
    uploaded_photo_urls = list(
        await session.scalars(
            select(UploadedPhoto.photo_url).where(UploadedPhoto.user_id == current_user.id)
        )
    )
    progress_photo_urls = list(
        await session.scalars(
            select(QuestProgress.photo_url).where(
                QuestProgress.user_id == current_user.id,
                QuestProgress.photo_url.is_not(None),
            )
        )
    )
    await repository.revoke_active_refresh_tokens(
        session,
        user_id=current_user.id,
        deleted_at=now,
    )
    await repository.hard_delete_consents(session, user_id=current_user.id)
    await session.execute(delete(UploadedPhoto).where(UploadedPhoto.user_id == current_user.id))
    # 사진 원본 링크만 지운다. 완료 횟수·지역 진행도 같은 비식별 집계 기반 기록은 남긴다.
    await session.execute(
        update(QuestProgress).where(QuestProgress.user_id == current_user.id).values(photo_url=None)
    )
    _anonymize_user(current_user, now)
    current_user.deleted_at = now
    current_user.withdrawal_grace_until = None
    await session.commit()
    # 컬럼만 비우면 공개 읽기 객체가 남아 "탈퇴 시 지체 없이 파기"와 어긋난다.
    await uploads_service.discard_stored_image(storage, profile_image_url)
    for photo_url in set(uploaded_photo_urls + progress_photo_urls):
        await uploads_service.discard_stored_image(storage, photo_url)


async def build_user_profile(session: AsyncSession, user: User) -> UserProfile:
    if not _profile_is_complete(user):
        onboarding_step = "profile"
    elif not await has_current_required_consents(session, user):
        onboarding_step = "profile"
    elif user.dna is None:
        onboarding_step = "trip_dna"
    else:
        onboarding_step = "complete"
    profile = UserProfile.model_validate(user)
    profile.onboarding_step = onboarding_step
    return profile


async def has_current_required_consents(session: AsyncSession, user: User) -> bool:
    return await repository.has_current_required_consents(
        session,
        user_id=user.id,
        terms_version=TERMS_CONSENT_VERSION,
        privacy_version=PRIVACY_CONSENT_VERSION,
    )


async def is_profiled_user(session: AsyncSession, user: User) -> bool:
    return _profile_is_complete(user) and await has_current_required_consents(session, user)


async def save_onboarding_profile(
    session: AsyncSession,
    *,
    current_user: User,
    payload: OnboardingProfileRequest,
    storage: PhotoStorage,
) -> UserProfile:
    if not is_at_least_fourteen(payload.birth_date):
        await reject_underage_onboarding(session, current_user=current_user, storage=storage)
        raise AppException(ErrorCode.UNDERAGE_SIGNUP_NOT_ALLOWED)
    if not payload.terms_agreed or not payload.privacy_agreed:
        raise AppException(ErrorCode.REQUIRED_CONSENT_ERROR)

    current_user = await require_active_user_for_update(session, current_user.id)
    # 이메일 수집을 폐지해 KAN-75의 이메일 잠금 로직도 함께 사라졌다.
    current_user.nickname = payload.nickname
    current_user.birth_date = payload.birth_date
    decided_at = now_kst()
    await repository.upsert_current_consents(
        session,
        user_id=current_user.id,
        decisions={
            "terms": (TERMS_CONSENT_VERSION, payload.terms_agreed, TERMS.digest, "explicit"),
            "privacy": (
                PRIVACY_CONSENT_VERSION,
                payload.privacy_agreed,
                PRIVACY.digest,
                "explicit",
            ),
        },
        decided_at=decided_at,
    )
    await session.commit()
    await session.refresh(current_user)
    return await build_user_profile(session, current_user)


async def reject_underage_onboarding(
    session: AsyncSession,
    *,
    current_user: User,
    storage: PhotoStorage,
) -> None:
    """Block and anonymize an incomplete account that submitted an underage birth date."""
    user = await require_active_user_for_update(session, current_user.id)
    profile_image_url = user.profile_image
    now = now_kst()
    await repository.revoke_active_refresh_tokens(session, user_id=user.id, deleted_at=now)
    await repository.hard_delete_consents(session, user_id=user.id)
    _anonymize_user(user, now)
    user.deleted_at = now
    await session.commit()
    await uploads_service.discard_stored_image(storage, profile_image_url)


async def replace_profile_image(
    session: AsyncSession,
    *,
    current_user: User,
    file: UploadFile,
    storage: PhotoStorage,
) -> UserProfile:
    """프로필 이미지를 업로드하고 `users.profile_image`를 갱신한다."""
    if not await is_profiled_user(session, current_user):
        raise AppException(ErrorCode.ONBOARDING_REQUIRED)
    image = await uploads_service.store_uploaded_image(file, storage, prefix="avatars")
    try:
        user = await require_active_user_for_update(session, current_user.id)
    except Exception:
        # 업로드 도중 다른 기기에서 탈퇴가 끝나면 여기서 막힌다. 이미 저장된 객체는
        # 어떤 행도 참조하지 않으므로 지우고 원래 예외를 그대로 올린다.
        await uploads_service.discard_stored_image(storage, image.url)
        raise
    previous_url = user.profile_image
    user.profile_image = image.url

    # commit 실패 시 `commit_or_discard_image`가 rollback한 뒤 이 콜백을 부른다. 그때는
    # `user`가 expire된 상태라 ORM 속성을 읽으면 lazy refresh IO가 일어나고, async
    # 컨텍스트 밖이라 MissingGreenlet으로 터져 원래 오류를 덮고 보상 삭제까지 건너뛴다.
    # 그래서 식별자를 미리 값으로 잡아둔다.
    user_id = user.id

    async def is_persisted(check_session: AsyncSession) -> bool:
        found = await check_session.scalar(
            select(User.id).where(User.id == user_id, User.profile_image == image.url)
        )
        return found is not None

    await uploads_service.commit_or_discard_image(
        session, storage, image, is_persisted=is_persisted
    )
    # 새 URL이 확정된 뒤에 이전 객체를 지운다. Kakao CDN 초기값은 건너뛴다.
    await uploads_service.discard_stored_image(storage, previous_url)
    await session.refresh(user)
    return await build_user_profile(session, user)


async def remove_profile_image(
    session: AsyncSession,
    *,
    current_user: User,
    storage: PhotoStorage,
) -> UserProfile:
    """프로필 이미지를 비우고 저장된 객체도 지운다. 이미 비어 있어도 성공한다(멱등).

    공개 읽기 스토리지라 컬럼만 비우면 URL을 아는 주체가 계속 읽을 수 있어,
    개인정보처리방침의 파기 문구와 어긋난다 (080-profile-image 의사결정 2).
    """
    user = await require_active_user_for_update(session, current_user.id)
    previous_url = user.profile_image
    user.profile_image = None
    await session.commit()
    await uploads_service.discard_stored_image(storage, previous_url)
    await session.refresh(user)
    return await build_user_profile(session, user)


async def update_current_user_profile(
    session: AsyncSession,
    *,
    current_user: User,
    payload: UserProfileUpdateRequest,
) -> UserProfile:
    current_user = await require_active_user_for_update(session, current_user.id)
    if not await is_profiled_user(session, current_user) or current_user.dna is None:
        raise AppException(ErrorCode.ONBOARDING_REQUIRED)
    if "nickname" in payload.model_fields_set:
        current_user.nickname = payload.nickname
    if "birth_date" in payload.model_fields_set:
        assert payload.birth_date is not None
        if not is_at_least_fourteen(payload.birth_date):
            raise AppException(ErrorCode.UNDERAGE_SIGNUP_NOT_ALLOWED)
        current_user.birth_date = payload.birth_date
    await session.commit()
    await session.refresh(current_user)
    return await build_user_profile(session, current_user)


def _issue_tokens(session: AsyncSession, user: User) -> AuthTokenData:
    access_token = create_access_token(user_id=user.id)
    refresh_token = create_refresh_token()
    session.add(
        RefreshToken(
            user_id=user.id,
            token_hash=hash_refresh_token(refresh_token),
            expires_at=now_kst() + timedelta(days=settings.refresh_token_ttl_days),
        )
    )
    return AuthTokenData(
        access_token=access_token,
        refresh_token=refresh_token,
        is_restored=False,
        user=UserProfile.model_validate(user),
    )


async def _sync_kakao_user(
    session: AsyncSession,
    kakao_user: KakaoUserInfo,
) -> tuple[User, bool]:
    user = await repository.get_user_by_social_identity_for_update(
        session,
        social_provider="kakao",
        social_id=kakao_user.social_id,
    )
    now = now_kst()
    is_restored = False

    if user is None:
        user = _new_kakao_user(kakao_user)
        session.add(user)
        await session.flush()
        return user, is_restored

    if user.deleted_at is not None:
        _anonymize_user(user, now)
        await repository.hard_delete_consents(session, user_id=user.id)
        await repository.revoke_active_refresh_tokens(session, user_id=user.id, deleted_at=now)
        await session.flush()
        user = _new_kakao_user(kakao_user)
        session.add(user)
        await session.flush()
        return user, is_restored

    return user, is_restored


def _new_kakao_user(kakao_user: KakaoUserInfo) -> User:
    return User(
        social_provider="kakao",
        social_id=kakao_user.social_id,
        nickname=kakao_user.nickname,
        birth_date=None,
        profile_image=kakao_user.profile_image,
    )


def _anonymize_user(user: User, now: datetime) -> None:
    user.social_id = f"deleted:{user.id}"
    user.nickname = None
    user.birth_date = None
    user.profile_image = None
    user.dna = None
    user.withdrawal_grace_until = None
    user.deleted_at = user.deleted_at or now
    user.anonymized_at = now


def _as_kst(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=now_kst().tzinfo)
    return value.astimezone(now_kst().tzinfo)


async def get_active_user(session: AsyncSession, user_id: UUID) -> User | None:
    return await repository.get_active_user(session, user_id)


async def require_active_user_for_update(session: AsyncSession, user_id: UUID) -> User:
    user = await repository.get_active_user_for_update(session, user_id)
    if user is None:
        raise AppException(ErrorCode.UNAUTHORIZED_ERROR, "Authenticated user is not active.")
    return user


def _profile_is_complete(user: User) -> bool:
    """온보딩 프로필 입력이 끝났는지 — 닉네임과 생년월일 둘 다 있어야 한다.

    이메일은 수집을 폐지해 제외한다. 생년월일은 KAN-75에서 잠시 선택이었으나 이
    브랜치에서 다시 필수로 되돌렸다 — 회원가입 화면이 두 값을 모두 받으므로 여기서
    비어 있을 수 없다.
    """
    return bool(user.nickname and user.nickname.strip() and user.birth_date is not None)
