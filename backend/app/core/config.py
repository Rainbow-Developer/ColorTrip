"""애플리케이션 설정 (pydantic-settings + .env).

규약: docs/conventions/backend.md (설정/환경변수)
"""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # DB
    database_url: str = "postgresql+asyncpg://colortrip:colortrip@localhost:5432/colortrip"

    # 한국관광공사 TourAPI
    tour_api_key: str = ""
    tour_api_base_url: str = "https://apis.data.go.kr/B551011/KorService2"


settings = Settings()
