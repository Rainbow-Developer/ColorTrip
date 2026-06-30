from __future__ import annotations

import os
from collections.abc import AsyncGenerator
from typing import Any

import pytest
from alembic.config import Config
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text
from sqlalchemy.engine import Connection

from alembic import command

TEST_DATABASE_URL = os.environ.get(
    "TEST_DATABASE_URL",
    "postgresql+asyncpg://colortrip:colortrip@localhost:5433/colortrip_test",
)

os.environ.setdefault("DATABASE_URL", TEST_DATABASE_URL)
os.environ.setdefault("APP_ENV", "test")
os.environ.setdefault("JWT_SECRET_KEY", "test-secret-key-at-least-32-bytes-long")
os.environ.setdefault("KAKAO_REST_API_KEY", "test-kakao-rest-api-key")
os.environ.setdefault("KAKAO_REDIRECT_URI", "http://127.0.0.1:8000/dev/kakao/callback")
os.environ.setdefault("ENABLE_DEV_AUTH_ROUTES", "true")


class MockKakaoClient:
    def __init__(
        self,
        *,
        token_users: dict[str, dict[str, str | None]],
        code_tokens: dict[str, str] | None = None,
    ) -> None:
        self._token_users = token_users
        self._code_tokens = code_tokens or {}
        self.requested_tokens: list[str] = []
        self.exchanged_codes: list[str] = []

    async def exchange_authorization_code(self, code: str) -> str:
        self.exchanged_codes.append(code)
        token = self._code_tokens.get(code)
        if token is None:
            from app.core.exceptions import AppException, ErrorCode

            raise AppException(
                ErrorCode.SOCIAL_AUTH_ERROR,
                "Kakao authorization code is invalid.",
            )
        return token

    async def get_user_info(self, access_token: str) -> Any:
        self.requested_tokens.append(access_token)
        user = self._token_users.get(access_token)
        if user is None:
            from app.core.exceptions import AppException, ErrorCode

            raise AppException(ErrorCode.SOCIAL_AUTH_ERROR, "Kakao token is invalid.")

        from app.auth.kakao import KakaoUserInfo

        return KakaoUserInfo(
            social_id=user["social_id"] or "",
            email=user.get("email"),
            nickname=user.get("nickname"),
        )


@pytest.fixture
def mock_kakao_client() -> MockKakaoClient:
    return MockKakaoClient(
        token_users={
            "kakao-token-1": {
                "social_id": "kakao-user-1",
                "email": "one@example.com",
                "nickname": "one",
            },
            "kakao-token-2": {
                "social_id": "kakao-user-1",
                "email": "one@example.com",
                "nickname": "one-restored",
            },
            "kakao-token-unknown": {
                "social_id": "kakao-user-unknown",
                "email": "unknown@example.com",
                "nickname": "unknown",
            },
        },
        code_tokens={"valid-code": "kakao-token-1"},
    )


@pytest.fixture
async def client(
    mock_kakao_client: MockKakaoClient,
) -> AsyncGenerator[AsyncClient]:
    if "colortrip_test" not in TEST_DATABASE_URL:
        pytest.fail("TEST_DATABASE_URL must point to colortrip_test.")

    from app.auth.kakao import get_kakao_client
    from app.core.database import engine
    from app.main import app

    app.dependency_overrides[get_kakao_client] = lambda: mock_kakao_client

    async with engine.begin() as conn:
        await conn.run_sync(_reset_database_with_migrations)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as api:
        yield api

    app.dependency_overrides.clear()


def _reset_database_with_migrations(connection: Connection) -> None:
    connection.execute(text("DROP TABLE IF EXISTS alembic_version"))
    for table_name in ("refresh_tokens", "users", "quests", "regions"):
        connection.execute(text(f"DROP TABLE IF EXISTS {table_name} CASCADE"))

    config = Config("alembic.ini")
    config.attributes["connection"] = connection
    command.upgrade(config, "head")
