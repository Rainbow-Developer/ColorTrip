"""프로필 이미지 업로드·제거 테스트 (docs/specs/080-profile-image/)."""

from uuid import UUID

from httpx import AsyncClient

from tests.helpers import auth_headers, login, seed_quest_fixture

_PNG_BYTES = b"\x89PNG\r\n\x1a\n" + b"0" * 32


def _active_headers(data: dict) -> dict[str, str]:
    """온보딩 전(`ActiveUser`) 헤더.

    `helpers.auth_headers`는 온보딩 PUT을 수행해 `ProfiledUser`가 되므로,
    회원가입 도중 상태를 재현하려면 로그인 응답의 토큰을 그대로 써야 한다.
    """
    return {"Authorization": f"Bearer {data['access_token']}"}


async def test_upload_before_onboarding_updates_profile(client: AsyncClient) -> None:
    data = await login(client)
    headers = _active_headers(data)

    response = await client.post(
        "/api/v1/users/me/profile-image",
        files={"file": ("profile.png", _PNG_BYTES, "image/png")},
        headers=headers,
    )

    assert response.status_code == 200
    profile = response.json()["data"]
    assert profile["profile_image"].startswith("/uploads/avatars/")
    assert profile["profile_image"].endswith(".png")
    # 이미지 등록만으로 온보딩이 끝나지 않는다 — 닉네임·생년월일·동의는 그대로 남는다.
    assert profile["onboarding_step"] == "profile"

    me = await client.get("/api/v1/users/me", headers=headers)
    assert me.json()["data"]["profile_image"] == profile["profile_image"]


async def test_upload_replaces_kakao_initial_image(client: AsyncClient) -> None:
    data = await login(client)
    assert data["user"]["profile_image"] == "https://example.com/one.png"
    headers = _active_headers(data)

    response = await client.post(
        "/api/v1/users/me/profile-image",
        files={"file": ("profile.png", _PNG_BYTES, "image/png")},
        headers=headers,
    )

    assert response.status_code == 200
    assert response.json()["data"]["profile_image"].startswith("/uploads/avatars/")


async def test_upload_rejects_non_image(client: AsyncClient) -> None:
    headers = _active_headers(await login(client))

    response = await client.post(
        "/api/v1/users/me/profile-image",
        files={"file": ("note.txt", b"hello", "text/plain")},
        headers=headers,
    )
    assert response.status_code == 422


async def test_upload_rejects_oversized(client: AsyncClient) -> None:
    from app.core.config import settings

    headers = _active_headers(await login(client))
    oversized = b"\x89PNG\r\n\x1a\n" + b"0" * (settings.max_upload_size_mb * 1024 * 1024 + 1)

    response = await client.post(
        "/api/v1/users/me/profile-image",
        files={"file": ("big.png", oversized, "image/png")},
        headers=headers,
    )
    assert response.status_code == 422


async def test_upload_rejects_empty_file(client: AsyncClient) -> None:
    headers = _active_headers(await login(client))

    response = await client.post(
        "/api/v1/users/me/profile-image",
        files={"file": ("empty.png", b"", "image/png")},
        headers=headers,
    )
    assert response.status_code == 422


async def test_upload_requires_auth(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/users/me/profile-image",
        files={"file": ("profile.png", _PNG_BYTES, "image/png")},
    )
    assert response.status_code == 401


async def test_delete_resets_to_null(client: AsyncClient) -> None:
    headers = _active_headers(await login(client))
    uploaded = await client.post(
        "/api/v1/users/me/profile-image",
        files={"file": ("profile.png", _PNG_BYTES, "image/png")},
        headers=headers,
    )
    assert uploaded.status_code == 200

    response = await client.delete("/api/v1/users/me/profile-image", headers=headers)

    assert response.status_code == 200
    assert response.json()["data"]["profile_image"] is None


async def test_delete_is_idempotent(client: AsyncClient) -> None:
    headers = _active_headers(await login(client))

    first = await client.delete("/api/v1/users/me/profile-image", headers=headers)
    second = await client.delete("/api/v1/users/me/profile-image", headers=headers)

    assert first.status_code == 200
    assert second.status_code == 200
    assert second.json()["data"]["profile_image"] is None


async def test_delete_requires_auth(client: AsyncClient) -> None:
    response = await client.delete("/api/v1/users/me/profile-image")
    assert response.status_code == 401


async def test_avatar_is_not_usable_as_quest_verification_photo(client: AsyncClient) -> None:
    """아바타는 `uploaded_photos` 소유권 행을 만들지 않는다 (plan.md 의사결정 4).

    행을 만들면 이 URL이 `require_owned_photo`를 통과해 사진 인증에 재사용된다.
    """
    seed = await seed_quest_fixture()
    data = await login(client)
    uploaded = await client.post(
        "/api/v1/users/me/profile-image",
        files={"file": ("profile.png", _PNG_BYTES, "image/png")},
        headers=_active_headers(data),
    )
    assert uploaded.status_code == 200
    avatar_url = uploaded.json()["data"]["profile_image"]

    from tests.helpers import complete_auth_headers

    headers = await complete_auth_headers(client, data)
    response = await client.post(
        f"/api/v1/quests/{seed['photo_quest_id']}/verify",
        json={"photo_url": avatar_url},
        headers=headers,
    )

    assert response.status_code == 422
    assert "본인이 업로드" in response.json()["message"]


async def test_withdrawal_clears_uploaded_profile_image(client: AsyncClient) -> None:
    data = await login(client)
    headers = await auth_headers(client)
    uploaded = await client.post(
        "/api/v1/users/me/profile-image",
        files={"file": ("profile.png", _PNG_BYTES, "image/png")},
        headers=headers,
    )
    assert uploaded.status_code == 200

    withdrawn = await client.delete("/api/v1/users/me", headers=headers)
    assert withdrawn.status_code == 200

    from app.auth.models import User
    from app.core.database import AsyncSessionLocal

    async with AsyncSessionLocal() as session:
        user = await session.get(User, UUID(data["user"]["id"]))
        assert user is not None
        assert user.profile_image is None
