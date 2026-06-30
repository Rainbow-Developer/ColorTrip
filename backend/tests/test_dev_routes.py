from __future__ import annotations

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_kakao_dev_login_page_is_not_registered(client: AsyncClient) -> None:
    response = await client.get("/dev/kakao-login-test")

    assert response.status_code == 404
