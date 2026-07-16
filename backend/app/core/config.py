"""애플리케이션 설정 (pydantic-settings + .env).

규약: docs/conventions/backend.md (설정/환경변수)
"""

from typing import Self

from pydantic import model_validator
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
    kakao_user_info_url: str = "https://kapi.kakao.com/v2/user/me"
    kakao_rest_api_key: str = ""
    kakao_redirect_uri: str = ""
    kakao_client_secret: str | None = None

    # 한국관광공사 TourAPI
    tour_api_key: str = ""
    tour_api_base_url: str = "https://apis.data.go.kr/B551011/KorService2"

    # 업로드(인증 사진) — docs/specs/010-journey/
    gcs_upload_bucket: str = ""  # 설정 시 GCS 사용(운영 기본), 미설정 시 로컬 디스크
    upload_dir: str = "./uploads"  # 로컬 스토리지 경로(개발·테스트)
    max_upload_size_mb: int = 10

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
        return self


settings = Settings()
