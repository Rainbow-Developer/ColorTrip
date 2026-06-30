"""auth — business logic."""

from datetime import datetime, timedelta
from uuid import UUID

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import repository
from app.auth.kakao import KakaoClient, KakaoUserInfo
from app.auth.models import RefreshToken, User
from app.auth.schemas import AuthTokenData, RefreshTokenRenewalData, UserProfile
from app.core.base import now_kst
from app.core.config import settings
from app.core.exceptions import AppException, ErrorCode
from app.core.security import create_access_token, create_refresh_token, hash_refresh_token


async def login_with_kakao_access_token(
    session: AsyncSession,
    *,
    kakao_access_token: str,
    kakao_client: KakaoClient,
) -> AuthTokenData:
    kakao_user = await kakao_client.get_user_info(kakao_access_token)
    last_error: IntegrityError | None = None

    for _ in range(2):
        try:
            user, is_restored = await _sync_kakao_user(session, kakao_user)
            token_data = _issue_tokens(session, user)
            await session.commit()
            await session.refresh(user)
            token_data.user = UserProfile.model_validate(user)
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
    token_row = await repository.get_refresh_token_by_hash(session, token_hash)
    if token_row is None or token_row.user_id != current_user.id:
        raise AppException(ErrorCode.UNAUTHORIZED_ERROR, "Refresh token is invalid.")
    if token_row.deleted_at is None:
        token_row.deleted_at = now_kst()
    await session.commit()


async def withdraw_current_user(session: AsyncSession, *, current_user: User) -> None:
    now = now_kst()
    current_user.deleted_at = now
    current_user.withdrawal_grace_until = now + timedelta(days=7)
    await repository.revoke_active_refresh_tokens(
        session,
        user_id=current_user.id,
        deleted_at=now,
    )
    await session.commit()


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
        if _is_within_withdrawal_grace(user, now):
            user.deleted_at = None
            user.withdrawal_grace_until = None
            user.email = kakao_user.email
            user.nickname = kakao_user.nickname
            is_restored = True
        else:
            _anonymize_user(user, now)
            await session.flush()
            user = _new_kakao_user(kakao_user)
            session.add(user)
            await session.flush()
        return user, is_restored

    user.email = kakao_user.email
    user.nickname = kakao_user.nickname
    return user, is_restored


def _new_kakao_user(kakao_user: KakaoUserInfo) -> User:
    return User(
        social_provider="kakao",
        social_id=kakao_user.social_id,
        email=kakao_user.email,
        nickname=kakao_user.nickname,
        birth_date=None,
    )


def _is_within_withdrawal_grace(user: User, now: datetime) -> bool:
    if user.withdrawal_grace_until is None:
        return False
    return _as_kst(user.withdrawal_grace_until) > now


def _anonymize_user(user: User, now: datetime) -> None:
    user.social_id = f"deleted:{user.id}"
    user.email = None
    user.nickname = None
    user.birth_date = None
    user.anonymized_at = now


def _as_kst(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=now_kst().tzinfo)
    return value.astimezone(now_kst().tzinfo)


async def get_active_user(session: AsyncSession, user_id: UUID) -> User | None:
    return await repository.get_active_user(session, user_id)
