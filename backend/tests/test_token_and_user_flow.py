from __future__ import annotations

import asyncio
from datetime import timedelta
from uuid import uuid4

import jwt
import pytest
from httpx import AsyncClient

from app.core.base import now_kst
from tests.helpers import login


@pytest.mark.asyncio
async def test_users_me_returns_current_user(client: AsyncClient) -> None:
    data = await login(client)

    response = await client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {data['access_token']}"},
    )

    assert response.status_code == 200
    assert response.json()["data"] == data["user"]


@pytest.mark.asyncio
async def test_current_user_rejects_authorization_errors(client: AsyncClient) -> None:
    missing = await client.get("/api/v1/users/me")
    non_bearer = await client.get(
        "/api/v1/users/me",
        headers={"Authorization": "Token abc"},
    )
    empty = await client.get(
        "/api/v1/users/me",
        headers={"Authorization": "Bearer "},
    )

    assert missing.status_code == 401
    assert non_bearer.status_code == 401
    assert empty.status_code == 401
    assert missing.json()["code"] == "UNAUTHORIZED_ERROR"
    assert non_bearer.json()["code"] == "UNAUTHORIZED_ERROR"
    assert empty.json()["code"] == "UNAUTHORIZED_ERROR"


@pytest.mark.asyncio
async def test_current_user_rejects_expired_invalid_and_unknown_jwt(
    client: AsyncClient,
) -> None:
    from app.core.config import settings
    from app.core.security import create_access_token

    data = await login(client)
    now = now_kst()
    expired = jwt.encode(
        {
            "sub": data["user"]["id"],
            "type": "access",
            "iat": int((now - timedelta(minutes=30)).timestamp()),
            "exp": int((now - timedelta(minutes=15)).timestamp()),
        },
        settings.jwt_secret_key,
        algorithm="HS256",
    )
    refresh_like = jwt.encode(
        {
            "sub": data["user"]["id"],
            "type": "refresh",
            "iat": int(now.timestamp()),
            "exp": int((now + timedelta(minutes=15)).timestamp()),
        },
        settings.jwt_secret_key,
        algorithm="HS256",
    )
    unknown = create_access_token(user_id=uuid4())

    expired_response = await client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {expired}"},
    )
    refresh_like_response = await client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {refresh_like}"},
    )
    unknown_response = await client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {unknown}"},
    )

    assert expired_response.status_code == 401
    assert expired_response.json()["code"] == "TOKEN_EXPIRED_ERROR"
    assert refresh_like_response.status_code == 401
    assert refresh_like_response.json()["code"] == "UNAUTHORIZED_ERROR"
    assert unknown_response.status_code == 401
    assert unknown_response.json()["code"] == "UNAUTHORIZED_ERROR"


@pytest.mark.asyncio
async def test_refresh_token_renewal_rotates_and_rejects_reuse(
    client: AsyncClient,
) -> None:
    data = await login(client)

    renewal = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": data["refresh_token"]},
    )
    reused_old = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": data["refresh_token"]},
    )
    reused_new = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": renewal.json()["data"]["refresh_token"]},
    )

    assert renewal.status_code == 200
    assert renewal.json()["data"]["refresh_token"] != data["refresh_token"]
    assert reused_old.status_code == 401
    assert reused_old.json()["code"] == "UNAUTHORIZED_ERROR"
    assert reused_new.status_code == 401
    assert reused_new.json()["code"] == "UNAUTHORIZED_ERROR"


@pytest.mark.asyncio
async def test_blank_refresh_token_requests_are_rejected(client: AsyncClient) -> None:
    data = await login(client)

    renewal = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": "   "},
    )
    logout = await client.request(
        "POST",
        "/api/v1/auth/logout",
        headers={"Authorization": f"Bearer {data['access_token']}"},
        json={"refresh_token": ""},
    )

    assert renewal.status_code == 422
    assert logout.status_code == 422


@pytest.mark.asyncio
async def test_concurrent_refresh_token_renewal_allows_only_one_success(
    client: AsyncClient,
) -> None:
    data = await login(client)

    responses = await asyncio.gather(
        *(
            client.post(
                "/api/v1/auth/refresh",
                json={"refresh_token": data["refresh_token"]},
            )
            for _ in range(5)
        )
    )

    successes = [response for response in responses if response.status_code == 200]
    failures = [response for response in responses if response.status_code == 401]

    assert len(successes) == 1
    assert len(failures) == 4
    assert all(response.json()["code"] == "UNAUTHORIZED_ERROR" for response in failures)


@pytest.mark.asyncio
async def test_logout_invalidates_refresh_token(client: AsyncClient) -> None:
    data = await login(client)

    logout = await client.request(
        "POST",
        "/api/v1/auth/logout",
        headers={"Authorization": f"Bearer {data['access_token']}"},
        json={"refresh_token": data["refresh_token"]},
    )
    renewal = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": data["refresh_token"]},
    )

    assert logout.status_code == 200
    assert logout.json()["data"] is None
    assert renewal.status_code == 401


@pytest.mark.asyncio
async def test_withdrawal_blocks_access_and_refresh_renewal(client: AsyncClient) -> None:
    data = await login(client)

    withdrawal = await client.delete(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {data['access_token']}"},
    )
    profile = await client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {data['access_token']}"},
    )
    renewal = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": data["refresh_token"]},
    )

    assert withdrawal.status_code == 200
    assert profile.status_code == 401
    assert renewal.status_code == 401
