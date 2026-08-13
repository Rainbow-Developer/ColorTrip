"""애플리케이션 설정 (pydantic-settings + .env).

규약: docs/conventions/backend.md (설정/환경변수)
"""

from typing import Self
from urllib.parse import urlparse

from pydantic import Field, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

DEFAULT_JWT_SECRET_KEY = "change-me-in-production-32-byte-minimum"
VALID_LOG_LEVELS = {"DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"}


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_env: str = "local"
    log_level: str | None = None

    # DB
    database_url: str = "postgresql+asyncpg://colortrip:colortrip@localhost:5432/colortrip"

    # Auth
    jwt_secret_key: str = DEFAULT_JWT_SECRET_KEY
    access_token_ttl_minutes: int = 15
    refresh_token_ttl_days: int = 14
    kakao_token_url: str = "https://kauth.kakao.com/oauth/token"
    kakao_token_info_url: str = "https://kapi.kakao.com/v1/user/access_token_info"
    kakao_user_info_url: str = "https://kapi.kakao.com/v2/user/me"
    kakao_app_id: int = Field(gt=0)
    kakao_rest_api_key: str = ""
    kakao_redirect_uri: str = ""
    kakao_client_secret: str | None = None

    # 한국관광공사 TourAPI
    tour_api_key: str = ""
    tour_api_base_url: str = "https://apis.data.go.kr/B551011/KorService2"

    # 사진 AI 인증 비전 판정 — docs/specs/050-quest-verification/
    # 키 미설정 시 스텁 판정(항상 통과 + "AI 미설정" 사유)으로 동작한다.
    gemini_api_key: str = ""
    gemini_model: str = "gemini-2.5-flash"
    gemini_base_url: str = "https://generativelanguage.googleapis.com"

    # QR 인증 페이로드 서명 키 — 미설정 시 JWT_SECRET_KEY에서 파생한다.
    qr_secret_key: str = ""

    # 지자체 오픈 API 서비스키 해시 키 — 미설정 시 JWT_SECRET_KEY에서 파생한다
    # (docs/specs/070-municipal-open-api). JWT_SECRET_KEY와 도메인을 분리해두면,
    # 사용자 세션 관련 사고로 JWT_SECRET_KEY를 회전시켜도 이미 발급한 지자체 키가
    # 함께 전부 무효화되지 않는다(반대 방향도 마찬가지).
    open_api_key_secret: str = ""

    # 업로드(인증 사진) — docs/specs/010-journey/
    gcs_upload_bucket: str = ""  # 설정 시 GCS 사용(운영 기본), 미설정 시 로컬 디스크
    upload_dir: str = "./uploads"  # 로컬 스토리지 경로(개발·테스트)
    max_upload_size_mb: int = 10

    # 공유 링크 발급 시 붙일 공개 도메인(Caddy가 서비스하는 HTTPS 호스트) — 미설정 시
    # 로컬 백엔드를 직접 가리킨다. 배포 환경에서는 deploy/docker-compose.yml이 API_DOMAIN에서
    # 파생해 주입한다(KAN-072 — 존재하지 않는 도메인으로 하드코딩되어 공유 링크가 무효했던 문제).
    share_base_url: str = "http://127.0.0.1:8000"

    # CORS — docs/conventions/auth-security.md (허용 도메인 화이트리스트)
    # 콤마 구분 도메인 목록. local/test는 "*" 허용, 그 외는 화이트리스트 필수
    cors_allowed_origins: str = "*"

    @property
    def cors_allowed_origins_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_allowed_origins.split(",") if origin.strip()]

    @field_validator("kakao_token_info_url")
    @classmethod
    def validate_kakao_token_info_url(cls, value: str) -> str:
        normalized = value.strip()
        parsed = urlparse(normalized)
        if parsed.scheme not in {"http", "https"} or not parsed.netloc:
            raise ValueError("KAKAO_TOKEN_INFO_URL must be a valid HTTP(S) URL.")
        return normalized

    @model_validator(mode="after")
    def validate_non_local_security(self) -> Self:
        if self.log_level is not None:
            log_level = self.log_level.strip().upper()
            if not log_level:
                self.log_level = None
            elif log_level not in VALID_LOG_LEVELS:
                raise ValueError("LOG_LEVEL must be one of DEBUG, INFO, WARNING, ERROR, CRITICAL.")
            else:
                self.log_level = log_level

        env = self.app_env.strip().lower()
        if env in {"local", "test"}:
            return self

        jwt_secret_key = self.jwt_secret_key.strip()
        if jwt_secret_key == DEFAULT_JWT_SECRET_KEY or not jwt_secret_key:
            raise ValueError("JWT_SECRET_KEY must be set outside local/test environments.")
        if len(jwt_secret_key) < 32:
            raise ValueError("JWT_SECRET_KEY must be at least 32 characters.")
        if not self.kakao_rest_api_key.strip():
            raise ValueError("KAKAO_REST_API_KEY must be set outside local/test environments.")
        if not self.kakao_redirect_uri.strip():
            raise ValueError("KAKAO_REDIRECT_URI must be set outside local/test environments.")
        if self.cors_allowed_origins.strip() == "*":
            raise ValueError(
                "CORS_ALLOWED_ORIGINS must be a domain whitelist outside local/test environments."
            )
        return self


settings = Settings()  # pyright: ignore[reportCallIssue]  # values may come from environment
