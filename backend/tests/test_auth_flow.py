from __future__ import annotations

import asyncio
from datetime import timedelta
from uuid import UUID

import pytest
from httpx import AsyncClient

from app.core.base import now_kst
from tests.helpers import login


@pytest.mark.asyncio
async def test_kakao_access_token_login_creates_user_and_tokens(
    client: AsyncClient,
) -> None:
    data = await login(client)

    assert data["token_type"] == "bearer"
    assert data["access_token"]
    assert data["refresh_token"]
    assert data["is_restored"] is False
    assert data["user"]["email"] == "one@example.com"
    assert data["user"]["social_provider"] == "kakao"


@pytest.mark.asyncio
async def test_kakao_authorization_code_login_exchanges_code(
    client: AsyncClient,
) -> None:
    response = await client.post(
        "/api/v1/auth-tokens",
        json={"provider": "kakao", "authorization_code": "valid-code"},
    )

    assert response.status_code == 200
    assert response.json()["status"] == 200
    assert response.json()["data"]["user"]["email"] == "one@example.com"


@pytest.mark.asyncio
async def test_invalid_kakao_token_returns_social_auth_error(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/auth-tokens",
        json={"provider": "kakao", "access_token": "invalid-token"},
    )

    assert response.status_code == 401
    assert response.json() == {
        "code": "SOCIAL_AUTH_ERROR",
        "status": 401,
        "message": "Kakao token is invalid.",
        "data": None,
    }


@pytest.mark.asyncio
async def test_same_kakao_login_reuses_active_user(client: AsyncClient) -> None:
    first = await login(client, "kakao-token-1")
    second = await login(client, "kakao-token-2")

    assert second["user"]["id"] == first["user"]["id"]
    assert second["is_restored"] is False


@pytest.mark.asyncio
async def test_concurrent_same_kakao_login_reuses_one_user(client: AsyncClient) -> None:
    responses = await asyncio.gather(
        *(
            client.post(
                "/api/v1/auth-tokens",
                json={"provider": "kakao", "access_token": "kakao-token-1"},
            )
            for _ in range(5)
        )
    )

    assert all(response.status_code == 200 for response in responses)
    user_ids = {response.json()["data"]["user"]["id"] for response in responses}
    assert len(user_ids) == 1


@pytest.mark.asyncio
async def test_withdrawn_user_restores_within_grace(client: AsyncClient) -> None:
    first = await login(client, "kakao-token-1")

    withdrawal = await client.delete(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {first['access_token']}"},
    )
    restored = await login(client, "kakao-token-2")

    assert withdrawal.status_code == 200
    assert restored["user"]["id"] == first["user"]["id"]
    assert restored["is_restored"] is True


@pytest.mark.asyncio
async def test_withdrawn_user_after_grace_anonymizes_and_creates_new_user(
    client: AsyncClient,
) -> None:
    first = await login(client, "kakao-token-1")
    old_user_id = UUID(first["user"]["id"])
    await client.delete(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {first['access_token']}"},
    )

    from app.auth.models import User
    from app.core.database import AsyncSessionLocal

    async with AsyncSessionLocal() as session:
        old_user = await session.get(User, old_user_id)
        assert old_user is not None
        old_user.deleted_at = now_kst() - timedelta(days=8)
        old_user.withdrawal_grace_until = now_kst() - timedelta(days=1)
        await session.commit()

    new_login = await login(client, "kakao-token-2")

    async with AsyncSessionLocal() as session:
        anonymized_user = await session.get(User, old_user_id)

    assert new_login["user"]["id"] != first["user"]["id"]
    assert new_login["is_restored"] is False
    assert anonymized_user is not None
    assert anonymized_user.social_id == f"deleted:{old_user_id}"
    assert anonymized_user.email is None
    assert anonymized_user.nickname is None
    assert anonymized_user.anonymized_at is not None
