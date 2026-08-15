from __future__ import annotations

import asyncio
import sys
from collections.abc import Callable
from typing import Any
from uuid import UUID

import pytest
from httpx import AsyncClient, Response
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import repository as auth_repository
from app.auth.models import User, UserConsent
from app.core.database import AsyncSessionLocal
from tests.helpers import complete_auth_headers, login


def _pause_first_matching_commit(
    monkeypatch: pytest.MonkeyPatch,
    predicate: Callable[[object], bool],
) -> tuple[asyncio.Event, asyncio.Event]:
    paused = asyncio.Event()
    resume = asyncio.Event()
    original_commit = AsyncSession.commit
    did_pause = False

    async def gated_commit(session: AsyncSession) -> None:
        nonlocal did_pause
        if not did_pause and any(predicate(obj) for obj in session.dirty):
            did_pause = True
            paused.set()
            await resume.wait()
        await original_commit(session)

    monkeypatch.setattr(AsyncSession, "commit", gated_commit)
    return paused, resume


async def _assert_mutation_holds_user_lock_until_commit(
    *,
    mutation_task: asyncio.Task[Response],
    paused: asyncio.Event,
    resume: asyncio.Event,
    client: AsyncClient,
    headers: dict[str, str],
) -> tuple[Response, Response]:
    await asyncio.wait_for(paused.wait(), timeout=2)
    withdrawal_task = asyncio.create_task(client.delete("/api/v1/users/me", headers=headers))
    results: tuple[Response, Response] | None = None
    try:
        await asyncio.sleep(0.1)
        assert not withdrawal_task.done()
    finally:
        resume.set()
        active_exception = sys.exc_info()[0] is not None
        try:
            results = await asyncio.wait_for(
                asyncio.gather(mutation_task, withdrawal_task),
                timeout=10,
            )
        except BaseException:
            if not active_exception:
                raise

    assert results is not None
    return results


@pytest.mark.asyncio
async def test_onboarding_update_serializes_with_withdrawal(
    client: AsyncClient,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    data = await login(client)
    user_id = UUID(data["user"]["id"])
    headers = {"Authorization": f"Bearer {data['access_token']}"}
    paused = asyncio.Event()
    resume = asyncio.Event()
    original_upsert = auth_repository.upsert_current_consents

    async def gated_upsert(*args: Any, **kwargs: Any) -> None:
        await original_upsert(*args, **kwargs)
        paused.set()
        await resume.wait()

    monkeypatch.setattr(auth_repository, "upsert_current_consents", gated_upsert)
    onboarding_task = asyncio.create_task(
        client.put(
            "/api/v1/users/me/onboarding-profile",
            headers=headers,
            json={
                "nickname": "race-onboarding",
                "birth_date": "2000-01-01",
                "terms_agreed": True,
                "privacy_agreed": True,
                "marketing_agreed": False,
            },
        )
    )

    onboarding, withdrawal = await _assert_mutation_holds_user_lock_until_commit(
        mutation_task=onboarding_task,
        paused=paused,
        resume=resume,
        client=client,
        headers=headers,
    )

    assert onboarding.status_code == 200
    assert withdrawal.status_code == 200
    await _assert_user_remains_anonymized(user_id)


@pytest.mark.asyncio
async def test_profile_patch_serializes_with_withdrawal(
    client: AsyncClient,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    data = await login(client)
    user_id = UUID(data["user"]["id"])
    headers = await complete_auth_headers(client, data)
    paused, resume = _pause_first_matching_commit(
        monkeypatch,
        lambda obj: isinstance(obj, User) and obj.nickname == "race-patch",
    )
    patch_task = asyncio.create_task(
        client.patch(
            "/api/v1/users/me",
            headers=headers,
            json={"nickname": "race-patch"},
        )
    )

    patch, withdrawal = await _assert_mutation_holds_user_lock_until_commit(
        mutation_task=patch_task,
        paused=paused,
        resume=resume,
        client=client,
        headers=headers,
    )

    assert patch.status_code == 200
    assert withdrawal.status_code == 200
    await _assert_user_remains_anonymized(user_id)


@pytest.mark.asyncio
async def test_concurrent_withdrawals_are_serialized(
    client: AsyncClient,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    data = await login(client)
    headers = {"Authorization": f"Bearer {data['access_token']}"}
    paused, resume = _pause_first_matching_commit(
        monkeypatch,
        lambda obj: isinstance(obj, User) and obj.deleted_at is not None,
    )
    first_task = asyncio.create_task(client.delete("/api/v1/users/me", headers=headers))
    await asyncio.wait_for(paused.wait(), timeout=2)
    second_task = asyncio.create_task(client.delete("/api/v1/users/me", headers=headers))
    try:
        await asyncio.sleep(0.1)
        assert not second_task.done()
    finally:
        resume.set()
        first, second = await asyncio.gather(first_task, second_task)

    assert first.status_code == 200
    assert second.status_code == 401


async def _assert_user_remains_anonymized(user_id: UUID) -> None:
    async with AsyncSessionLocal() as session:
        user = await session.get(User, user_id)
        consent_count = await session.scalar(
            select(func.count()).select_from(UserConsent).where(UserConsent.user_id == user_id)
        )
    assert user is not None
    assert user.deleted_at is not None
    assert user.anonymized_at is not None
    assert user.social_id == f"deleted:{user_id}"
    assert user.nickname is None
    assert user.birth_date is None
    assert user.profile_image is None
    assert user.dna is None
    assert consent_count == 0
