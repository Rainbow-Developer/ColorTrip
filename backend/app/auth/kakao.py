"""Kakao login client.

규약: docs/conventions/auth-security.md
"""

from collections.abc import AsyncGenerator
from dataclasses import dataclass
from typing import Any, Protocol, Self

import httpx

from app.core.config import settings
from app.core.exceptions import AppException, ErrorCode


@dataclass(frozen=True)
class KakaoUserInfo:
    social_id: str
    email: str | None
    nickname: str | None


class KakaoClient(Protocol):
    async def exchange_authorization_code(self, code: str) -> str: ...

    async def get_user_info(self, access_token: str) -> KakaoUserInfo: ...


class HttpKakaoClient:
    def __init__(self, http_client: httpx.AsyncClient | None = None) -> None:
        self._client = http_client or httpx.AsyncClient(timeout=10.0)
        self._owns_client = http_client is None

    async def __aenter__(self) -> Self:
        return self

    async def __aexit__(self, *exc: object) -> None:
        await self.aclose()

    async def aclose(self) -> None:
        if self._owns_client:
            await self._client.aclose()

    async def exchange_authorization_code(self, code: str) -> str:
        payload: dict[str, str] = {
            "grant_type": "authorization_code",
            "client_id": settings.kakao_rest_api_key,
            "redirect_uri": settings.kakao_redirect_uri,
            "code": code,
        }
        if settings.kakao_client_secret:
            payload["client_secret"] = settings.kakao_client_secret

        try:
            response = await self._client.post(settings.kakao_token_url, data=payload)
        except httpx.HTTPError as exc:
            raise AppException(ErrorCode.SOCIAL_AUTH_ERROR, "Kakao token API failed.") from exc

        if response.status_code != 200:
            raise AppException(
                ErrorCode.SOCIAL_AUTH_ERROR,
                "Kakao authorization code is invalid.",
            )

        data = _json_object(response, "Kakao token API failed.")
        access_token = data.get("access_token")
        if not isinstance(access_token, str) or not access_token:
            raise AppException(ErrorCode.SOCIAL_AUTH_ERROR, "Kakao token API failed.")
        return access_token

    async def get_user_info(self, access_token: str) -> KakaoUserInfo:
        try:
            response = await self._client.get(
                settings.kakao_user_info_url,
                headers={"Authorization": f"Bearer {access_token}"},
            )
        except httpx.HTTPError as exc:
            raise AppException(ErrorCode.SOCIAL_AUTH_ERROR, "Kakao user API failed.") from exc

        if response.status_code != 200:
            raise AppException(ErrorCode.SOCIAL_AUTH_ERROR, "Kakao token is invalid.")

        data = _json_object(response, "Kakao user API failed.")
        social_id = data.get("id")
        if social_id is None:
            raise AppException(ErrorCode.SOCIAL_AUTH_ERROR, "Kakao user API failed.")

        account = data.get("kakao_account")
        profile: dict[str, Any] = {}
        if isinstance(account, dict):
            profile_raw = account.get("profile")
            if isinstance(profile_raw, dict):
                profile = profile_raw

        email = account.get("email") if isinstance(account, dict) else None
        nickname = profile.get("nickname")
        return KakaoUserInfo(
            social_id=str(social_id),
            email=email if isinstance(email, str) else None,
            nickname=nickname if isinstance(nickname, str) else None,
        )


async def get_kakao_client() -> AsyncGenerator[KakaoClient]:
    async with HttpKakaoClient() as client:
        yield client


def _json_object(response: httpx.Response, error_message: str) -> dict[str, Any]:
    try:
        data: Any = response.json()
    except ValueError as exc:
        raise AppException(ErrorCode.SOCIAL_AUTH_ERROR, error_message) from exc

    if not isinstance(data, dict):
        raise AppException(ErrorCode.SOCIAL_AUTH_ERROR, error_message)
    return data
