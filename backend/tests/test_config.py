from __future__ import annotations

from pathlib import Path
from typing import Any, cast

import pytest
import yaml

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
        share_base_url="https://colortrip.p-e.kr",
    )

    assert settings.app_env == "dev"
    assert settings.share_base_url == "https://colortrip.p-e.kr"


def test_non_local_env_requires_release_legal_disclosures() -> None:
    with pytest.raises(ValueError, match="LEGAL_OPERATOR_NAME"):
        _settings(
            app_env="dev",
            jwt_secret_key="dev-secret-key-at-least-32-bytes-long",
            kakao_rest_api_key="test-kakao-rest-api-key",
            kakao_redirect_uri="https://example.com/auth/kakao/callback",
            cors_allowed_origins="https://example.com",
            share_base_url="https://colortrip.p-e.kr",
            legal_operator_name="",
        )


def test_non_local_env_rejects_default_share_base_url() -> None:
    with pytest.raises(ValueError, match="SHARE_BASE_URL must use HTTPS"):
        _settings(
            app_env="dev",
            jwt_secret_key="dev-secret-key-at-least-32-bytes-long",
            kakao_rest_api_key="test-kakao-rest-api-key",
            kakao_redirect_uri="https://example.com/auth/kakao/callback",
            cors_allowed_origins="https://example.com",
        )


def test_non_local_env_rejects_http_share_base_url() -> None:
    with pytest.raises(ValueError, match="SHARE_BASE_URL must use HTTPS"):
        _settings(
            app_env="dev",
            jwt_secret_key="dev-secret-key-at-least-32-bytes-long",
            kakao_rest_api_key="test-kakao-rest-api-key",
            kakao_redirect_uri="https://example.com/auth/kakao/callback",
            cors_allowed_origins="https://example.com",
            share_base_url="http://colortrip.p-e.kr",
        )


@pytest.mark.parametrize(
    "share_base_url",
    [
        "https://localhost:8000",
        "https://127.0.0.1:8000",
        "https://10.0.2.2:8000",
    ],
)
def test_non_local_env_rejects_local_share_base_url(share_base_url: str) -> None:
    with pytest.raises(ValueError, match="SHARE_BASE_URL must not use a local host"):
        _settings(
            app_env="dev",
            jwt_secret_key="dev-secret-key-at-least-32-bytes-long",
            kakao_rest_api_key="test-kakao-rest-api-key",
            kakao_redirect_uri="https://example.com/auth/kakao/callback",
            cors_allowed_origins="https://example.com",
            share_base_url=share_base_url,
        )


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


@pytest.mark.parametrize("share_base_url", ["", "   ", "colortrip.app", "ftp://example.com"])
def test_share_base_url_must_be_http_url(share_base_url: str) -> None:
    with pytest.raises(ValueError, match="SHARE_BASE_URL"):
        _settings(app_env="test", share_base_url=share_base_url)


def test_share_base_url_is_normalized() -> None:
    settings = _settings(
        app_env="test",
        share_base_url=" https://api.example.com/ ",
    )

    assert settings.share_base_url == "https://api.example.com"


def test_local_env_allows_local_defaults() -> None:
    settings = _settings(
        app_env="local",
        jwt_secret_key=DEFAULT_JWT_SECRET_KEY,
    )

    assert settings.app_env == "local"


def test_local_compose_passes_required_kakao_token_info_configuration() -> None:
    compose = (BACKEND_ROOT / "docker-compose.yml").read_text(encoding="utf-8")
    data = yaml.safe_load(compose)
    api_environment = data["services"]["api"]["environment"]

    assert api_environment["KAKAO_APP_ID"].startswith("${KAKAO_APP_ID:")
    assert (
        api_environment["KAKAO_TOKEN_INFO_URL"]
        == "${KAKAO_TOKEN_INFO_URL:-https://kapi.kakao.com/v1/user/access_token_info}"
    )
    assert api_environment["SHARE_BASE_URL"] == "${SHARE_BASE_URL:-http://10.0.2.2:8000}"


def test_dev_workflow_validates_kakao_app_id_before_remote_shell() -> None:
    workflow_path = REPOSITORY_ROOT / ".github" / "workflows" / "deploy-dev.yml"
    workflow = workflow_path.read_text(encoding="utf-8")

    assert "KAKAO_APP_ID: ${{ vars.KAKAO_APP_ID }}" in workflow
    assert '[[ ! "${KAKAO_APP_ID}" =~ ^[1-9][0-9]*$ ]]' in workflow
    assert "KAKAO_APP_ID='${{ vars.KAKAO_APP_ID }}'" not in workflow


def _settings(**kwargs: Any) -> Settings:
    kwargs.setdefault("kakao_app_id", 12345)
    kwargs.setdefault("legal_operator_name", "ColorTrip 운영자")
    kwargs.setdefault("legal_terms_version", "terms-v2")
    kwargs.setdefault("legal_privacy_version", "privacy-v2")
    kwargs.setdefault("legal_document_effective_date", "2026-08-15")
    kwargs.setdefault("legal_operator_email", "privacy@example.com")
    kwargs.setdefault("legal_operator_address", "서울특별시 예시로 1")
    kwargs.setdefault("legal_privacy_officer_name", "개인정보 담당자")
    kwargs.setdefault("legal_privacy_officer_email", "privacy@example.com")
    kwargs.setdefault("legal_gcs_processor_name", "Google LLC")
    kwargs.setdefault("legal_gcs_processing_country", "대한민국")
    kwargs.setdefault("legal_gcs_region", "asia-northeast3")
    kwargs.setdefault("legal_gemini_processor_name", "Google LLC")
    kwargs.setdefault("legal_gemini_processing_country", "미국")
    kwargs.setdefault("legal_gemini_retention_period", "Google 계약 및 설정에 따름")
    kwargs.setdefault("legal_share_retention_period", "공유 철회 또는 회원 탈퇴 시까지")
    kwargs.setdefault("legal_aggregate_retention_period", "익명화 후 서비스 운영 기간")
    settings_cls = cast(Any, Settings)
    return settings_cls(_env_file=None, **kwargs)
