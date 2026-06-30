"""애플리케이션 설정 (pydantic-settings + .env).

규약: docs/conventions/backend.md (설정/환경변수)
"""

from typing import Self

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

DEFAULT_JWT_SECRET_KEY = "change-me-in-production-32-byte-minimum"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_env: str = "local"

    # DB
    database_url: str = "postgresql+asyncpg://colortrip:colortrip@localhost:5432/colortrip"

    # Auth
    jwt_secret_key: str = DEFAULT_JWT_SECRET_KEY
    access_token_ttl_minutes: int = 15
    refresh_token_ttl_days: int = 14
    kakao_authorize_url: str = "https://kauth.kakao.com/oauth/authorize"
    kakao_token_url: str = "https://kauth.kakao.com/oauth/token"
    kakao_user_info_url: str = "https://kapi.kakao.com/v2/user/me"
    kakao_rest_api_key: str = ""
    kakao_redirect_uri: str = "http://127.0.0.1:8000/dev/kakao/callback"
    kakao_client_secret: str | None = None
    enable_dev_auth_routes: bool = False

    # 한국관광공사 TourAPI
    tour_api_key: str = ""
    tour_api_base_url: str = "https://apis.data.go.kr/B551011/KorService2"

    @model_validator(mode="after")
    def validate_non_local_security(self) -> Self:
        env = self.app_env.strip().lower()
        if env in {"local", "test"}:
            return self

        if self.jwt_secret_key == DEFAULT_JWT_SECRET_KEY or not self.jwt_secret_key.strip():
            raise ValueError("JWT_SECRET_KEY must be set outside local/test environments.")
        if len(self.jwt_secret_key) < 32:
            raise ValueError("JWT_SECRET_KEY must be at least 32 characters.")
        if self.enable_dev_auth_routes:
            raise ValueError("ENABLE_DEV_AUTH_ROUTES must be false outside local/test.")
        return self


settings = Settings()
