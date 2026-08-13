"""인증 사진 업로드 테스트 (docs/specs/010-journey/ VRF-03) — 로컬 스토리지."""

import pytest
from httpx import AsyncClient

from app.core.config import settings
from tests.helpers import auth_headers

_PNG_BYTES = b"\x89PNG\r\n\x1a\n" + b"0" * 32


async def test_upload_photo(client: AsyncClient) -> None:
    headers = await auth_headers(client)

    response = await client.post(
        "/api/v1/uploads/photo",
        files={"file": ("visit.png", _PNG_BYTES, "image/png")},
        headers=headers,
    )
    assert response.status_code == 201
    photo_url = response.json()["data"]["photo_url"]
    assert photo_url.startswith("/uploads/photos/")
    assert photo_url.endswith(".png")


async def test_upload_rejects_non_image(client: AsyncClient) -> None:
    headers = await auth_headers(client)

    response = await client.post(
        "/api/v1/uploads/photo",
        files={"file": ("note.txt", b"hello", "text/plain")},
        headers=headers,
    )
    assert response.status_code == 422


async def test_upload_rejects_oversized(client: AsyncClient) -> None:
    from app.core.config import settings

    headers = await auth_headers(client)
    oversized = b"\x89PNG\r\n\x1a\n" + b"0" * (settings.max_upload_size_mb * 1024 * 1024 + 1)

    response = await client.post(
        "/api/v1/uploads/photo",
        files={"file": ("big.png", oversized, "image/png")},
        headers=headers,
    )
    assert response.status_code == 422


async def test_upload_requires_auth(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/uploads/photo",
        files={"file": ("visit.png", _PNG_BYTES, "image/png")},
    )
    assert response.status_code == 401


# --- photo_url → object_name 역변환 (KAN-73) ---


def test_object_name_from_url_local_mode(monkeypatch: pytest.MonkeyPatch) -> None:
    """로컬 스토리지 모드에서는 `/uploads/{object}` 형태만 인정한다."""
    from app.uploads.storage import object_name_from_url

    monkeypatch.setattr(settings, "gcs_upload_bucket", "")

    assert object_name_from_url("/uploads/photos/2026/07/a.jpg") == "photos/2026/07/a.jpg"
    assert object_name_from_url("/uploads/") is None  # 객체 이름이 비어 있음
    assert object_name_from_url("photos/a.jpg") is None  # prefix 없음
    assert object_name_from_url("https://storage.googleapis.com/b/photos/a.jpg") is None


def test_object_name_from_url_gcs_mode(monkeypatch: pytest.MonkeyPatch) -> None:
    """GCS 모드에서는 설정된 버킷의 공개 URL만 인정한다 — 형식이 바뀌면 판정이 거절된다."""
    from app.uploads.storage import object_name_from_url

    monkeypatch.setattr(settings, "gcs_upload_bucket", "colortrip-uploads")

    assert (
        object_name_from_url(
            "https://storage.googleapis.com/colortrip-uploads/photos/2026/07/a.jpg"
        )
        == "photos/2026/07/a.jpg"
    )
    # 다른 버킷·로컬 경로·prefix만 있는 URL은 인정하지 않는다(fail-closed).
    assert object_name_from_url("https://storage.googleapis.com/other-bucket/photos/a.jpg") is None
    assert object_name_from_url("/uploads/photos/a.jpg") is None
    assert object_name_from_url("https://storage.googleapis.com/colortrip-uploads/") is None
