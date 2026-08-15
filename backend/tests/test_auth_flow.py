from __future__ import annotations

import asyncio
from typing import Any
from uuid import UUID

import pytest
from httpx import AsyncClient
from sqlalchemy import func, select

from app.auth.models import RefreshToken, User, UserConsent
from app.core.database import AsyncSessionLocal
from app.core.security import hash_refresh_token
from app.trip_dna.models import UserDnaHistory
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
    assert data["user"]["social_provider"] == "kakao"
    assert data["user"]["profile_image"] == "https://example.com/one.png"
    assert data["user"]["dna"] is None
    assert data["user"]["onboarding_step"] == "profile"
    assert data["user"]["is_restored"] is False


@pytest.mark.asyncio
async def test_kakao_authorization_code_login_exchanges_code(
    client: AsyncClient,
    mock_kakao_client: Any,
) -> None:
    response = await client.post(
        "/api/v1/auth/login/social",
        json={"provider": "kakao", "authorization_code": "valid-code"},
    )

    assert response.status_code == 200
    assert response.json()["status"] == 200
    assert response.json()["data"]["user"]["nickname"] == "one"
    assert mock_kakao_client.exchanged_codes == ["valid-code"]
    assert mock_kakao_client.validated_tokens == ["kakao-token-1"]


@pytest.mark.asyncio
async def test_invalid_kakao_token_returns_social_auth_error(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/auth/login/social",
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
async def test_blank_kakao_credentials_are_rejected(client: AsyncClient) -> None:
    blank_access_token = await client.post(
        "/api/v1/auth/login/social",
        json={"provider": "kakao", "access_token": "   "},
    )
    blank_authorization_code = await client.post(
        "/api/v1/auth/login/social",
        json={"provider": "kakao", "authorization_code": ""},
    )

    assert blank_access_token.status_code == 422
    assert blank_authorization_code.status_code == 422


@pytest.mark.asyncio
async def test_same_kakao_login_reuses_active_user(
    client: AsyncClient,
    mock_kakao_client: Any,
) -> None:
    first = await login(client, "kakao-token-1")
    second = await login(client, "kakao-token-2")

    assert second["user"]["id"] == first["user"]["id"]
    assert second["is_restored"] is False
    assert second["user"]["nickname"] == "one"
    assert second["user"]["profile_image"] == "https://example.com/one.png"
    assert mock_kakao_client.validated_tokens == ["kakao-token-1", "kakao-token-2"]


@pytest.mark.asyncio
async def test_kakao_relogin_does_not_overwrite_completed_colortrip_profile(
    client: AsyncClient,
) -> None:
    first = await login(client, "kakao-token-1")
    headers = {"Authorization": f"Bearer {first['access_token']}"}
    onboarding = await client.put(
        "/api/v1/users/me/onboarding-profile",
        headers=headers,
        json={
            "nickname": "내가 정한 닉네임",
            "birth_date": "1999-12-31",
            "terms_agreed": True,
            "privacy_agreed": True,
            "marketing_agreed": False,
        },
    )

    relogin = await login(client, "kakao-token-2")

    assert onboarding.status_code == 200
    assert relogin["user"]["nickname"] == "내가 정한 닉네임"
    assert relogin["user"]["birth_date"] == "1999-12-31"
    assert relogin["user"]["profile_image"] == "https://example.com/one.png"


@pytest.mark.asyncio
async def test_concurrent_same_kakao_login_reuses_one_user(client: AsyncClient) -> None:
    responses = await asyncio.gather(
        *(
            client.post(
                "/api/v1/auth/login/social",
                json={"provider": "kakao", "access_token": "kakao-token-1"},
            )
            for _ in range(5)
        )
    )

    assert all(response.status_code == 200 for response in responses)
    user_ids = {response.json()["data"]["user"]["id"] for response in responses}
    assert len(user_ids) == 1


@pytest.mark.asyncio
async def test_withdrawal_immediately_anonymizes_and_never_restores(
    client: AsyncClient,
) -> None:
    first = await login(client, "kakao-token-1")
    user_id = UUID(first["user"]["id"])
    headers = {"Authorization": f"Bearer {first['access_token']}"}
    await client.put(
        "/api/v1/users/me/onboarding-profile",
        headers=headers,
        json={
            "nickname": "컬러트립",
            "birth_date": "2000-01-02",
            "terms_agreed": True,
            "privacy_agreed": True,
            "marketing_agreed": False,
        },
    )
    async with AsyncSessionLocal() as session:
        user = await session.get(User, user_id)
        assert user is not None
        user.dna = "nature"
        user.profile_image = "https://example.com/profile.png"
        session.add(UserDnaHistory(user_id=user_id, dna="nature"))
        await session.commit()

    withdrawal = await client.delete(
        "/api/v1/users/me",
        headers=headers,
    )
    async with AsyncSessionLocal() as session:
        anonymized_user = await session.get(User, user_id)
        refresh_row = await session.scalar(
            select(RefreshToken).where(
                RefreshToken.token_hash == hash_refresh_token(first["refresh_token"])
            )
        )
        consent_count = await session.scalar(
            select(func.count()).select_from(UserConsent).where(UserConsent.user_id == user_id)
        )
        dna_history_count = await session.scalar(
            select(func.count())
            .select_from(UserDnaHistory)
            .where(UserDnaHistory.user_id == user_id)
        )
    new_login = await login(client, "kakao-token-2")

    assert withdrawal.status_code == 200
    assert new_login["user"]["id"] != first["user"]["id"]
    assert new_login["is_restored"] is False
    assert anonymized_user is not None
    assert anonymized_user.social_id == f"deleted:{user_id}"
    assert anonymized_user.nickname is None
    assert anonymized_user.birth_date is None
    assert anonymized_user.profile_image is None
    assert anonymized_user.dna is None
    assert anonymized_user.deleted_at is not None
    assert anonymized_user.anonymized_at is not None
    assert anonymized_user.withdrawal_grace_until is None
    assert refresh_row is not None
    assert refresh_row.deleted_at is not None
    assert consent_count == 0
    assert dna_history_count == 1
