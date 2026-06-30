"""auth — database access."""

from datetime import datetime
from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.models import RefreshToken, User


async def get_user_by_social_identity(
    session: AsyncSession,
    *,
    social_provider: str,
    social_id: str,
) -> User | None:
    stmt = select(User).where(
        User.social_provider == social_provider,
        User.social_id == social_id,
        User.anonymized_at.is_(None),
    )
    return await session.scalar(stmt)


async def get_user_by_social_identity_for_update(
    session: AsyncSession,
    *,
    social_provider: str,
    social_id: str,
) -> User | None:
    stmt = (
        select(User)
        .where(
            User.social_provider == social_provider,
            User.social_id == social_id,
            User.anonymized_at.is_(None),
        )
        .with_for_update()
    )
    return await session.scalar(stmt)


async def get_active_user(session: AsyncSession, user_id: UUID) -> User | None:
    stmt = select(User).where(
        User.id == user_id,
        User.deleted_at.is_(None),
        User.anonymized_at.is_(None),
    )
    return await session.scalar(stmt)


async def get_refresh_token_by_hash(
    session: AsyncSession,
    token_hash: str,
) -> RefreshToken | None:
    stmt = select(RefreshToken).where(RefreshToken.token_hash == token_hash)
    return await session.scalar(stmt)


async def get_refresh_token_by_hash_for_update(
    session: AsyncSession,
    token_hash: str,
) -> RefreshToken | None:
    stmt = select(RefreshToken).where(RefreshToken.token_hash == token_hash).with_for_update()
    return await session.scalar(stmt)


async def revoke_active_refresh_tokens(
    session: AsyncSession,
    *,
    user_id: UUID,
    deleted_at: datetime,
) -> None:
    stmt = (
        update(RefreshToken)
        .where(
            RefreshToken.user_id == user_id,
            RefreshToken.deleted_at.is_(None),
        )
        .values(deleted_at=deleted_at)
    )
    await session.execute(stmt)
