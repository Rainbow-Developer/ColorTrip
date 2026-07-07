from __future__ import annotations

from typing import Any

from httpx import AsyncClient


async def login(client: AsyncClient, token: str = "kakao-token-1") -> dict[str, Any]:
    response = await client.post(
        "/api/v1/auth/login/social",
        json={"provider": "kakao", "access_token": token},
    )
    assert response.status_code == 200
    return response.json()["data"]
