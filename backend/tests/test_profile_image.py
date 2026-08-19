"""프로필 이미지 업로드·제거 테스트 (docs/specs/080-profile-image/)."""

from pathlib import Path
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


async def test_upload_before_onboarding_is_rejected(client: AsyncClient) -> None:
    data = await login(client)
    headers = _active_headers(data)

    response = await client.post(
        "/api/v1/users/me/profile-image",
        files={"file": ("profile.png", _PNG_BYTES, "image/png")},
        headers=headers,
    )

    assert response.status_code == 403


async def test_upload_replaces_kakao_initial_image(client: AsyncClient) -> None:
    data = await login(client)
    assert data["user"]["profile_image"] == "https://example.com/one.png"
    headers = await auth_headers(client)

    response = await client.post(
        "/api/v1/users/me/profile-image",
        files={"file": ("profile.png", _PNG_BYTES, "image/png")},
        headers=headers,
    )

    assert response.status_code == 200
    assert response.json()["data"]["profile_image"].startswith("/uploads/avatars/")


async def test_upload_rejects_non_image(client: AsyncClient) -> None:
    headers = await auth_headers(client)

    response = await client.post(
        "/api/v1/users/me/profile-image",
        files={"file": ("note.txt", b"hello", "text/plain")},
        headers=headers,
    )
    assert response.status_code == 422


async def test_upload_rejects_oversized(client: AsyncClient) -> None:
    from app.core.config import settings

    headers = await auth_headers(client)
    oversized = b"\x89PNG\r\n\x1a\n" + b"0" * (settings.max_upload_size_mb * 1024 * 1024 + 1)

    response = await client.post(
        "/api/v1/users/me/profile-image",
        files={"file": ("big.png", oversized, "image/png")},
        headers=headers,
    )
    assert response.status_code == 422


async def test_upload_rejects_mime_spoofed_bytes(client: AsyncClient) -> None:
    """헤더만 이미지로 위장한 바이트는 저장하지 않는다 — 렌더링 불가한 URL이 남는다."""
    headers = await auth_headers(client)

    response = await client.post(
        "/api/v1/users/me/profile-image",
        files={"file": ("profile.png", b"not an image at all", "image/png")},
        headers=headers,
    )
    assert response.status_code == 422

    me = await client.get("/api/v1/users/me", headers=headers)
    # 카카오 초기값이 그대로 남고 위장 파일로 덮이지 않아야 한다.
    assert me.json()["data"]["profile_image"] == "https://example.com/one.png"


async def test_upload_rejects_mismatched_image_format(client: AsyncClient) -> None:
    """실제 PNG를 image/jpeg로 선언하면 거부한다."""
    headers = await auth_headers(client)

    response = await client.post(
        "/api/v1/users/me/profile-image",
        files={"file": ("profile.jpg", _PNG_BYTES, "image/jpeg")},
        headers=headers,
    )
    assert response.status_code == 422


async def test_upload_rejects_empty_file(client: AsyncClient) -> None:
    headers = await auth_headers(client)

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
    headers = await auth_headers(client)
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
    headers = await auth_headers(client)

    first = await client.delete("/api/v1/users/me/profile-image", headers=headers)
    second = await client.delete("/api/v1/users/me/profile-image", headers=headers)

    assert first.status_code == 200
    assert second.status_code == 200
    assert second.json()["data"]["profile_image"] is None


async def test_delete_requires_auth(client: AsyncClient) -> None:
    response = await client.delete("/api/v1/users/me/profile-image")
    assert response.status_code == 401


def _stored_path(photo_url: str) -> Path:
    from app.core.config import settings

    return Path(settings.upload_dir) / photo_url.removeprefix("/uploads/")


async def test_delete_removes_the_stored_object(client: AsyncClient) -> None:
    """컬럼만 비우면 공개 읽기 객체가 남아 URL을 아는 주체가 계속 읽을 수 있다."""
    headers = await auth_headers(client)
    uploaded = await client.post(
        "/api/v1/users/me/profile-image",
        files={"file": ("profile.png", _PNG_BYTES, "image/png")},
        headers=headers,
    )
    stored = _stored_path(uploaded.json()["data"]["profile_image"])
    assert stored.exists()

    await client.delete("/api/v1/users/me/profile-image", headers=headers)

    assert not stored.exists()


async def test_replace_removes_the_previous_object(client: AsyncClient) -> None:
    headers = await auth_headers(client)
    first = await client.post(
        "/api/v1/users/me/profile-image",
        files={"file": ("profile.png", _PNG_BYTES, "image/png")},
        headers=headers,
    )
    old = _stored_path(first.json()["data"]["profile_image"])
    assert old.exists()

    second = await client.post(
        "/api/v1/users/me/profile-image",
        files={"file": ("profile.png", _PNG_BYTES, "image/png")},
        headers=headers,
    )
    new = _stored_path(second.json()["data"]["profile_image"])

    assert not old.exists()
    assert new.exists()


async def test_replace_keeps_the_kakao_initial_image(client: AsyncClient) -> None:
    """카카오 CDN URL은 우리 객체가 아니므로 삭제를 시도하지 않는다."""
    from app.uploads.storage import object_name_from_url

    assert object_name_from_url("https://example.com/one.png") is None

    headers = await auth_headers(client)
    response = await client.post(
        "/api/v1/users/me/profile-image",
        files={"file": ("profile.png", _PNG_BYTES, "image/png")},
        headers=headers,
    )

    # 외부 URL 교체가 예외 없이 끝나고 새 이미지가 저장된다.
    assert response.status_code == 200
    assert _stored_path(response.json()["data"]["profile_image"]).exists()


async def test_object_name_from_url_rejects_path_traversal() -> None:
    """DB 값이 오염돼도 스토리지 바깥을 지우지 못해야 한다."""
    from app.uploads.storage import object_name_from_url

    assert object_name_from_url("/uploads/../../etc/passwd") is None
    assert object_name_from_url("/uploads/") is None
    assert object_name_from_url(None) is None
    # 절대 경로 — `Path(base) / "/tmp/x"`는 base를 통째로 무시하고 `/tmp/x`가 된다.
    assert object_name_from_url("/uploads//tmp/passwd") is None
    assert object_name_from_url("/uploads/\\windows\\system32") is None
    assert object_name_from_url("/uploads/avatars/a.png") == "avatars/a.png"


async def test_local_storage_refuses_paths_outside_the_upload_root() -> None:
    """이름 검사를 거치지 않고 직접 호출돼도 루트 밖을 건드리지 않아야 한다."""
    import pytest

    from app.uploads.storage import LocalPhotoStorage

    storage = LocalPhotoStorage("/var/colortrip-uploads")

    for escaping in ("/tmp/passwd", "../../etc/passwd"):
        with pytest.raises(ValueError, match="업로드 경로를 벗어난"):
            await storage.delete(escaping)
        with pytest.raises(ValueError, match="업로드 경로를 벗어난"):
            await storage.load(escaping)


async def test_upload_cleans_up_when_the_user_becomes_inactive(
    client: AsyncClient,
) -> None:
    """저장 뒤 사용자 재확인이 실패하면 방금 올린 객체를 남기지 않는다."""
    import io

    import pytest
    from fastapi import UploadFile
    from starlette.datastructures import Headers

    from app.auth import service as auth_service
    from app.auth.models import User
    from app.core.base import now_kst
    from app.core.config import settings
    from app.core.database import AsyncSessionLocal
    from app.core.exceptions import AppException
    from app.uploads.storage import get_photo_storage

    data = await login(client)
    headers = await auth_headers(client)
    me = await client.get("/api/v1/users/me", headers=headers)
    assert me.status_code == 200
    assert me.json()["data"]["id"] == data["user"]["id"]
    user_id = UUID(data["user"]["id"])
    avatars = Path(settings.upload_dir) / "avatars"
    before = set(avatars.rglob("*.png")) if avatars.exists() else set()

    async with AsyncSessionLocal() as session:
        user = await session.get(User, user_id)
        assert user is not None
        # 업로드 도중 다른 기기에서 탈퇴가 끝난 상황을 재현한다.
        user.deleted_at = now_kst()
        await session.commit()

    async with AsyncSessionLocal() as session:
        stale = await session.get(User, user_id)
        assert stale is not None
        with pytest.raises(AppException):
            await auth_service.replace_profile_image(
                session,
                current_user=stale,
                file=UploadFile(
                    file=io.BytesIO(_PNG_BYTES),
                    filename="profile.png",
                    headers=Headers({"content-type": "image/png"}),
                ),
                storage=get_photo_storage(),
            )

    leaked = (set(avatars.rglob("*.png")) if avatars.exists() else set()) - before
    assert leaked == set(), f"탈퇴 경합으로 고아 객체가 남았습니다: {leaked}"


async def test_commit_failure_cleans_up_and_surfaces_the_original_error(
    client: AsyncClient,
) -> None:
    """commit이 실패하면 원래 예외가 그대로 올라오고 저장된 객체는 정리돼야 한다.

    회귀 가드: `is_persisted` 콜백은 rollback 이후에 실행된다. 거기서 ORM 속성
    (`user.id`)을 읽으면 expire된 인스턴스가 lazy refresh를 시도해 async 컨텍스트 밖에서
    `MissingGreenlet`으로 터진다 — 원래 오류가 가려지고 보상 삭제도 건너뛰어 방금 올린
    아바타가 고아 객체로 남는다. 식별자를 값으로 미리 잡아야 한다.
    """
    import io

    import pytest
    from fastapi import UploadFile
    from starlette.datastructures import Headers

    from app.auth import service as auth_service
    from app.auth.models import User
    from app.core.config import settings
    from app.core.database import AsyncSessionLocal
    from app.uploads.storage import get_photo_storage

    data = await login(client)
    headers = await auth_headers(client)
    me = await client.get("/api/v1/users/me", headers=headers)
    assert me.status_code == 200
    assert me.json()["data"]["id"] == data["user"]["id"]
    user_id = UUID(data["user"]["id"])
    upload = UploadFile(
        file=io.BytesIO(_PNG_BYTES),
        filename="profile.png",
        headers=Headers({"content-type": "image/png"}),
    )

    # 업로드 디렉토리는 세션 전체가 공유하므로, 이 테스트가 새로 만든 파일만 본다.
    avatars = Path(settings.upload_dir) / "avatars"
    before = set(avatars.rglob("*.png")) if avatars.exists() else set()

    class _CommitFails(Exception):
        """commit 단계에서만 터지는 고유 예외 — 이 타입이 그대로 올라와야 한다."""

    async with AsyncSessionLocal() as session:
        user = await session.get(User, user_id)
        assert user is not None

        async def _boom() -> None:
            raise _CommitFails

        session.commit = _boom  # type: ignore[method-assign]

        with pytest.raises(_CommitFails):
            await auth_service.replace_profile_image(
                session,
                current_user=user,
                file=upload,
                storage=get_photo_storage(),
            )

    # 저장은 됐지만 DB에 남지 않았으므로 이번에 만든 객체는 지워져 있어야 한다.
    leaked = (set(avatars.rglob("*.png")) if avatars.exists() else set()) - before
    assert leaked == set(), f"보상 삭제가 되지 않아 고아 객체가 남았습니다: {leaked}"

    # DB도 이전 상태(카카오 초기값) 그대로여야 한다.
    async with AsyncSessionLocal() as session:
        user = await session.get(User, user_id)
        assert user is not None
        assert user.profile_image == "https://example.com/one.png"


async def test_avatar_is_not_usable_as_quest_verification_photo(client: AsyncClient) -> None:
    """아바타는 `uploaded_photos` 소유권 행을 만들지 않는다 (plan.md 의사결정 4).

    행을 만들면 이 URL이 `require_owned_photo`를 통과해 사진 인증에 재사용된다.
    """
    seed = await seed_quest_fixture()
    await login(client)
    headers = await auth_headers(client)
    uploaded = await client.post(
        "/api/v1/users/me/profile-image",
        files={"file": ("profile.png", _PNG_BYTES, "image/png")},
        headers=headers,
    )
    assert uploaded.status_code == 200
    avatar_url = uploaded.json()["data"]["profile_image"]

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
    # 같은 Kakao social_id로 로그인하므로 동일 사용자여야 한다. 이 전제가 깨지면
    # 아래 단언이 다른 사용자를 조회해 조용히 통과한다.
    me = await client.get("/api/v1/users/me", headers=headers)
    assert me.json()["data"]["id"] == data["user"]["id"]

    uploaded = await client.post(
        "/api/v1/users/me/profile-image",
        files={"file": ("profile.png", _PNG_BYTES, "image/png")},
        headers=headers,
    )
    assert uploaded.status_code == 200

    stored = _stored_path(uploaded.json()["data"]["profile_image"])
    assert stored.exists()

    withdrawn = await client.delete("/api/v1/users/me", headers=headers)
    assert withdrawn.status_code == 200
    # "탈퇴 시 지체 없이 파기" — 컬럼뿐 아니라 저장된 객체도 사라져야 한다.
    assert not stored.exists()

    from app.auth.models import User
    from app.core.database import AsyncSessionLocal

    async with AsyncSessionLocal() as session:
        user = await session.get(User, UUID(data["user"]["id"]))
        assert user is not None
        assert user.profile_image is None
