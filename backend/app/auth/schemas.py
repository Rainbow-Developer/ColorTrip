"""auth — API schemas."""

from datetime import date
from typing import Literal, Self
from uuid import UUID

from pydantic import BaseModel, ConfigDict, model_validator


class AuthTokenRequest(BaseModel):
    provider: Literal["kakao"]
    access_token: str | None = None
    authorization_code: str | None = None

    @model_validator(mode="after")
    def validate_token_source(self) -> Self:
        has_access_token = self.access_token is not None
        has_authorization_code = self.authorization_code is not None
        if has_access_token == has_authorization_code:
            raise ValueError("Provide exactly one of access_token or authorization_code.")
        return self


class UserProfile(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    email: str | None
    nickname: str | None
    birth_date: date | None
    social_provider: Literal["kakao"]


class AuthTokenData(BaseModel):
    access_token: str
    refresh_token: str
    token_type: Literal["bearer"] = "bearer"
    is_restored: bool
    user: UserProfile


class RefreshTokenRenewalRequest(BaseModel):
    refresh_token: str


class RefreshTokenRenewalData(BaseModel):
    access_token: str
    refresh_token: str
    token_type: Literal["bearer"] = "bearer"


class LogoutRequest(BaseModel):
    refresh_token: str
