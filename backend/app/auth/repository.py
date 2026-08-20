"""auth — database access."""

from datetime import datetime
from uuid import UUID

from sqlalchemy import delete, select, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.models import RefreshToken, User, UserConsent
from app.core.base import new_uuid7


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


async def get_active_user_for_update(session: AsyncSession, user_id: UUID) -> User | None:
    stmt = (
        select(User)
        .where(
            User.id == user_id,
            User.deleted_at.is_(None),
            User.anonymized_at.is_(None),
        )
        .with_for_update()
        .execution_options(populate_existing=True)
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


async def has_current_required_consents(
    session: AsyncSession,
    *,
    user_id: UUID,
    terms_version: str,
    privacy_version: str,
) -> bool:
    stmt = select(UserConsent.consent_type).where(
        UserConsent.user_id == user_id,
        UserConsent.agreed.is_(True),
        (
            ((UserConsent.consent_type == "terms") & (UserConsent.version == terms_version))
            | ((UserConsent.consent_type == "privacy") & (UserConsent.version == privacy_version))
        ),
    )
    return set(await session.scalars(stmt)) == {"terms", "privacy"}


async def upsert_current_consents(
    session: AsyncSession,
    *,
    user_id: UUID,
    decisions: dict[str, tuple[str, bool, str, str]],
    decided_at: datetime,
) -> None:
    for consent_type, (version, agreed, document_digest, source) in decisions.items():
        stmt = (
            insert(UserConsent)
            .values(
                id=new_uuid7(),
                user_id=user_id,
                consent_type=consent_type,
                version=version,
                agreed=agreed,
                document_digest=document_digest,
                source=source,
                decided_at=decided_at,
                created_at=decided_at,
                updated_at=decided_at,
            )
            .on_conflict_do_update(
                constraint="uq_user_consents_user_type_version",
                set_={
                    "agreed": agreed,
                    "decided_at": decided_at,
                    "updated_at": decided_at,
                    "document_digest": document_digest,
                    "source": source,
                },
                where=UserConsent.agreed.is_distinct_from(agreed),
            )
        )
        await session.execute(stmt)


async def hard_delete_consents(session: AsyncSession, *, user_id: UUID) -> None:
    await session.execute(delete(UserConsent).where(UserConsent.user_id == user_id))
