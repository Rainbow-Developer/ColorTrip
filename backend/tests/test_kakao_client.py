from __future__ import annotations

import pytest
from httpx import AsyncClient, MockTransport, Request, Response

from app.auth.kakao import HttpKakaoClient
from app.core.exceptions import AppException, ErrorCode


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
