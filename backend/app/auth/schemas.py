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
        if self.access_token is not None and not self.access_token.strip():
            raise ValueError("access_token must not be blank.")
        if self.authorization_code is not None and not self.authorization_code.strip():
            raise ValueError("authorization_code must not be blank.")
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

    @model_validator(mode="after")
    def validate_refresh_token(self) -> Self:
        if not self.refresh_token.strip():
            raise ValueError("refresh_token must not be blank.")
        return self


class RefreshTokenRenewalData(BaseModel):
    access_token: str
    refresh_token: str
    token_type: Literal["bearer"] = "bearer"


class LogoutRequest(BaseModel):
    refresh_token: str

    @model_validator(mode="after")
    def validate_refresh_token(self) -> Self:
        if not self.refresh_token.strip():
            raise ValueError("refresh_token must not be blank.")
        return self
