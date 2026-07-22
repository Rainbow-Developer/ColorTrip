from __future__ import annotations

from typing import Any, cast

import pytest

from app.core.config import Settings

DEFAULT_JWT_SECRET_KEY = "change-me-in-production-32-byte-minimum"


def test_non_local_env_rejects_default_jwt_secret() -> None:
    with pytest.raises(ValueError, match="JWT_SECRET_KEY"):
        _settings(
            app_env="dev",
            jwt_secret_key=DEFAULT_JWT_SECRET_KEY,
        )


def test_non_local_env_rejects_missing_kakao_rest_api_key() -> None:
    with pytest.raises(ValueError, match="KAKAO_REST_API_KEY"):
        _settings(
            app_env="dev",
            jwt_secret_key="dev-secret-key-at-least-32-bytes-long",
            kakao_rest_api_key="",
            kakao_redirect_uri="https://example.com/auth/kakao/callback",
        )


def test_non_local_env_rejects_space_padded_short_jwt_secret() -> None:
    with pytest.raises(ValueError, match="JWT_SECRET_KEY must be at least 32 characters"):
        _settings(
            app_env="dev",
            jwt_secret_key="short-secret                    ",
            kakao_rest_api_key="test-kakao-rest-api-key",
            kakao_redirect_uri="https://example.com/auth/kakao/callback",
        )


def test_non_local_env_rejects_missing_kakao_redirect_uri() -> None:
    with pytest.raises(ValueError, match="KAKAO_REDIRECT_URI"):
        _settings(
            app_env="dev",
            jwt_secret_key="dev-secret-key-at-least-32-bytes-long",
            kakao_rest_api_key="test-kakao-rest-api-key",
            kakao_redirect_uri="",
        )


def test_non_local_env_rejects_wildcard_cors() -> None:
    with pytest.raises(ValueError, match="CORS_ALLOWED_ORIGINS"):
        _settings(
            app_env="dev",
            jwt_secret_key="dev-secret-key-at-least-32-bytes-long",
            kakao_rest_api_key="test-kakao-rest-api-key",
            kakao_redirect_uri="https://example.com/auth/kakao/callback",
            cors_allowed_origins="*",
        )


def test_non_local_env_accepts_required_auth_settings() -> None:
    settings = _settings(
        app_env="dev",
        jwt_secret_key="dev-secret-key-at-least-32-bytes-long",
        kakao_rest_api_key="test-kakao-rest-api-key",
        kakao_redirect_uri="https://example.com/auth/kakao/callback",
        cors_allowed_origins="https://example.com",
    )

    assert settings.app_env == "dev"


def test_local_env_allows_local_defaults() -> None:
    settings = _settings(
        app_env="local",
        jwt_secret_key=DEFAULT_JWT_SECRET_KEY,
    )

    assert settings.app_env == "local"


def _settings(**kwargs: Any) -> Settings:
    settings_cls = cast(Any, Settings)
    return settings_cls(_env_file=None, **kwargs)
