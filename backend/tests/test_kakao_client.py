from __future__ import annotations

import pytest
from httpx import AsyncClient, MockTransport, Request, Response

from app.auth.kakao import HttpKakaoClient
from app.core.config import settings
from app.core.exceptions import AppException, ErrorCode


@pytest.mark.asyncio
async def test_kakao_access_token_is_validated_before_user_info(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(settings, "kakao_app_id", 12345)
    requests: list[Request] = []

    async def handler(request: Request) -> Response:
        requests.append(request)
        if request.url == settings.kakao_token_info_url:
            return Response(200, json={"id": 77, "app_id": 12345}, request=request)
        return Response(
            200,
            json={
                "id": 77,
                "kakao_account": {
                    "profile": {
                        "nickname": "one",
                        "profile_image_url": "https://example.com/profile.png",
                    },
                },
            },
            request=request,
        )

    async with AsyncClient(transport=MockTransport(handler)) as http_client:
        kakao_client = HttpKakaoClient(http_client)
        await kakao_client.validate_access_token("access-token")
        user = await kakao_client.get_user_info("access-token")

    assert [request.url for request in requests] == [
        settings.kakao_token_info_url,
        settings.kakao_user_info_url,
    ]
    assert all(request.headers["Authorization"] == "Bearer access-token" for request in requests)
    assert user.nickname == "one"
    assert user.profile_image == "https://example.com/profile.png"


@pytest.mark.asyncio
async def test_kakao_token_info_rejects_mismatched_app_id(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(settings, "kakao_app_id", 12345)

    async def handler(request: Request) -> Response:
        return Response(200, json={"id": 77, "app_id": 99999}, request=request)

    async with AsyncClient(transport=MockTransport(handler)) as http_client:
        kakao_client = HttpKakaoClient(http_client)

        with pytest.raises(AppException) as exc_info:
            await kakao_client.validate_access_token("access-token")

    assert exc_info.value.error is ErrorCode.SOCIAL_AUTH_ERROR
    assert exc_info.value.message == "Kakao token is invalid."


@pytest.mark.asyncio
async def test_kakao_token_info_timeout_is_normalized() -> None:
    async def handler(request: Request) -> Response:
        from httpx import ReadTimeout

        raise ReadTimeout("slow", request=request)

    async with AsyncClient(transport=MockTransport(handler)) as http_client:
        kakao_client = HttpKakaoClient(http_client)

        with pytest.raises(AppException) as exc_info:
            await kakao_client.validate_access_token("access-token")

    assert exc_info.value.error is ErrorCode.SOCIAL_AUTH_ERROR
    assert exc_info.value.message == "Kakao token validation failed."


def test_default_kakao_http_timeout_is_bounded() -> None:
    kakao_client = HttpKakaoClient()

    try:
        assert kakao_client._client.timeout.connect == 5.0
        assert kakao_client._client.timeout.read == 5.0
    finally:
        import asyncio

        asyncio.run(kakao_client.aclose())


@pytest.mark.asyncio
async def test_kakao_token_api_invalid_json_returns_social_auth_error() -> None:
    async def handler(request: Request) -> Response:
        return Response(200, text="not-json", request=request)

    async with AsyncClient(transport=MockTransport(handler)) as http_client:
        kakao_client = HttpKakaoClient(http_client)

        with pytest.raises(AppException) as exc_info:
            await kakao_client.exchange_authorization_code("code")

    assert exc_info.value.error is ErrorCode.SOCIAL_AUTH_ERROR


@pytest.mark.asyncio
async def test_kakao_user_api_invalid_json_shape_returns_social_auth_error() -> None:
    async def handler(request: Request) -> Response:
        return Response(200, json=[], request=request)

    async with AsyncClient(transport=MockTransport(handler)) as http_client:
        kakao_client = HttpKakaoClient(http_client)

        with pytest.raises(AppException) as exc_info:
            await kakao_client.get_user_info("access-token")

    assert exc_info.value.error is ErrorCode.SOCIAL_AUTH_ERROR


@pytest.mark.asyncio
async def test_kakao_user_api_invalid_id_shape_returns_social_auth_error() -> None:
    async def handler(request: Request) -> Response:
        return Response(200, json={"id": []}, request=request)

    async with AsyncClient(transport=MockTransport(handler)) as http_client:
        kakao_client = HttpKakaoClient(http_client)

        with pytest.raises(AppException) as exc_info:
            await kakao_client.get_user_info("access-token")

    assert exc_info.value.error is ErrorCode.SOCIAL_AUTH_ERROR
