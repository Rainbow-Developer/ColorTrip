"""auth — API schemas."""

from datetime import date
from typing import Literal, Self
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, StrictBool, field_validator, model_validator

from app.core.base import now_kst
from app.core.enums import DnaType


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
    nickname: str | None
    birth_date: date | None
    profile_image: str | None
    dna: DnaType | None
    social_provider: Literal["kakao"]
    onboarding_step: Literal["profile", "trip_dna", "complete"] = "profile"
    is_restored: bool = False


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


def _normalize_nickname(value: object) -> object:
    return value.strip() if isinstance(value, str) else value


def _validate_birth_date(value: date) -> date:
    if value > now_kst().date():
        raise ValueError("birth_date must not be in the future.")
    return value


class OnboardingProfileRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    nickname: str = Field(min_length=1, max_length=30)
    birth_date: date
    terms_agreed: StrictBool
    privacy_agreed: StrictBool

    _strip_nickname = field_validator("nickname", mode="before")(_normalize_nickname)
    _valid_birth_date = field_validator("birth_date")(_validate_birth_date)


class UserProfileUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    nickname: str | None = Field(default=None, min_length=1, max_length=30)
    birth_date: date | None = None

    _strip_nickname = field_validator("nickname", mode="before")(_normalize_nickname)

    @field_validator("nickname")
    @classmethod
    def reject_null_nickname(cls, value: str | None) -> str | None:
        if value is None:
            raise ValueError("nickname must not be null.")
        return value

    @field_validator("birth_date")
    @classmethod
    def validate_optional_birth_date(cls, value: date | None) -> date | None:
        if value is None:
            raise ValueError("birth_date must not be null.")
        return _validate_birth_date(value)

    @model_validator(mode="after")
    def require_update(self) -> Self:
        if not self.model_fields_set:
            raise ValueError("Provide at least one profile field.")
        return self
