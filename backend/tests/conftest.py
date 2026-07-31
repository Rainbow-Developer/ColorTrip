from __future__ import annotations

import os
import tempfile
from collections.abc import AsyncGenerator
from typing import Any

import pytest
from alembic.config import Config
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text
from sqlalchemy.engine import Connection, make_url
from sqlalchemy.exc import ArgumentError

from alembic import command

TEST_DATABASE_URL = os.environ.get(
    "TEST_DATABASE_URL",
    "postgresql+asyncpg://colortrip:colortrip@localhost:5433/colortrip_test",
)
TEST_DATABASE_NAME = "colortrip_test"

os.environ.setdefault("DATABASE_URL", TEST_DATABASE_URL)
os.environ.setdefault("APP_ENV", "test")
os.environ.setdefault("JWT_SECRET_KEY", "test-secret-key-at-least-32-bytes-long")
os.environ.setdefault("KAKAO_REST_API_KEY", "test-kakao-rest-api-key")
os.environ.setdefault("KAKAO_REDIRECT_URI", "http://localhost:3000/auth/kakao/callback")
os.environ.setdefault("KAKAO_APP_ID", "12345")
os.environ.setdefault("UPLOAD_DIR", os.path.join(tempfile.gettempdir(), "colortrip-test-uploads"))


class MockKakaoClient:
    def __init__(
        self,
        *,
        token_users: dict[str, dict[str, str | None]],
        code_tokens: dict[str, str] | None = None,
    ) -> None:
        self._token_users = token_users
        self._code_tokens = code_tokens or {}
        self.validated_tokens: list[str] = []
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

    async def validate_access_token(self, access_token: str) -> None:
        self.validated_tokens.append(access_token)
        if access_token not in self._token_users:
            from app.core.exceptions import AppException, ErrorCode

            raise AppException(ErrorCode.SOCIAL_AUTH_ERROR, "Kakao token is invalid.")

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
            profile_image=user.get("profile_image"),
        )


@pytest.fixture
def mock_kakao_client() -> MockKakaoClient:
    return MockKakaoClient(
        token_users={
            "kakao-token-1": {
                "social_id": "kakao-user-1",
                "email": "one@example.com",
                "nickname": "one",
                "profile_image": "https://example.com/one.png",
            },
            "kakao-token-2": {
                "social_id": "kakao-user-1",
                "email": "one@example.com",
                "nickname": "one-restored",
                "profile_image": "https://example.com/two.png",
            },
            "kakao-token-unknown": {
                "social_id": "kakao-user-unknown",
                "email": "unknown@example.com",
                "nickname": "unknown",
                "profile_image": None,
            },
        },
        code_tokens={"valid-code": "kakao-token-1"},
    )


@pytest.fixture
async def client(
    mock_kakao_client: MockKakaoClient,
) -> AsyncGenerator[AsyncClient]:
    # 엔진이 실제로 바인딩하는 DATABASE_URL을 검사한다(환경에 다른 DB가 설정돼 있으면
    # setdefault가 덮어쓰지 않으므로, TEST_DATABASE_URL만 확인하면 파괴적 리셋이 오작동할 수 있다).
    _assert_test_database_url(os.environ.get("DATABASE_URL", ""))

    from app.auth.kakao import get_kakao_client
    from app.core.database import engine
    from app.main import app

    app.dependency_overrides[get_kakao_client] = lambda: mock_kakao_client

    try:
        async with engine.begin() as conn:
            await conn.run_sync(_reset_database_with_migrations)

        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://testserver") as api:
            yield api
    finally:
        app.dependency_overrides.clear()


def _reset_database_with_migrations(connection: Connection) -> None:
    _assert_test_database_url(os.environ.get("DATABASE_URL", ""))

    schema_name = connection.execute(text("SELECT current_schema()")).scalar_one()
    if schema_name in {"information_schema", "pg_catalog"}:
        raise RuntimeError(f"Refusing to reset system schema: {schema_name}")

    quoted_schema_name = _quote_identifier(schema_name)
    connection.execute(text(f"DROP SCHEMA {quoted_schema_name} CASCADE"))
    connection.execute(text(f"CREATE SCHEMA {quoted_schema_name}"))

    config = Config("alembic.ini")
    config.attributes["connection"] = connection
    command.upgrade(config, "head")


def _quote_identifier(identifier: str) -> str:
    return '"' + identifier.replace('"', '""') + '"'


def _assert_test_database_url(database_url: str) -> None:
    try:
        database_name = make_url(database_url).database
    except ArgumentError as exc:
        pytest.fail(f"DATABASE_URL is invalid: {exc}")

    if database_name != TEST_DATABASE_NAME:
        pytest.fail(
            "DATABASE_URL database must be exactly "
            f"{TEST_DATABASE_NAME!r} before running destructive fixtures."
        )
