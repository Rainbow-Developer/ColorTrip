from __future__ import annotations

from pathlib import Path
from typing import Any, cast

import pytest

from app.core.config import Settings

DEFAULT_JWT_SECRET_KEY = "change-me-in-production-32-byte-minimum"
BACKEND_ROOT = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = BACKEND_ROOT.parent


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


@pytest.mark.parametrize("kakao_app_id", [0, -1])
def test_kakao_app_id_must_be_positive(kakao_app_id: int) -> None:
    with pytest.raises(ValueError, match="kakao_app_id"):
        _settings(app_env="test", kakao_app_id=kakao_app_id)


def test_kakao_app_id_is_normalized_to_integer() -> None:
    settings = _settings(app_env="test", kakao_app_id="12345")

    assert settings.kakao_app_id == 12345
    assert isinstance(settings.kakao_app_id, int)


@pytest.mark.parametrize("token_info_url", ["", "   ", "ftp://example.com/token-info"])
def test_kakao_token_info_url_must_be_http_url(token_info_url: str) -> None:
    with pytest.raises(ValueError, match="KAKAO_TOKEN_INFO_URL"):
        _settings(app_env="test", kakao_token_info_url=token_info_url)


def test_local_env_allows_local_defaults() -> None:
    settings = _settings(
        app_env="local",
        jwt_secret_key=DEFAULT_JWT_SECRET_KEY,
    )

    assert settings.app_env == "local"


def test_local_compose_passes_required_kakao_token_info_configuration() -> None:
    compose = (BACKEND_ROOT / "docker-compose.yml").read_text(encoding="utf-8")

    assert "KAKAO_APP_ID:" in compose
    assert "KAKAO_TOKEN_INFO_URL:" in compose


def test_dev_workflow_validates_kakao_app_id_before_remote_shell() -> None:
    workflow_path = REPOSITORY_ROOT / ".github" / "workflows" / "deploy-dev.yml"
    workflow = workflow_path.read_text(encoding="utf-8")

    assert "KAKAO_APP_ID: ${{ vars.KAKAO_APP_ID }}" in workflow
    assert '[[ ! "${KAKAO_APP_ID}" =~ ^[1-9][0-9]*$ ]]' in workflow
    assert "KAKAO_APP_ID='${{ vars.KAKAO_APP_ID }}'" not in workflow


def _settings(**kwargs: Any) -> Settings:
    kwargs.setdefault("kakao_app_id", 12345)
    settings_cls = cast(Any, Settings)
    return settings_cls(_env_file=None, **kwargs)
