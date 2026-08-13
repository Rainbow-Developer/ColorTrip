"""인증 사진 업로드 테스트 (docs/specs/010-journey/ VRF-03) — 로컬 스토리지."""

from httpx import AsyncClient

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


async def test_upload_records_photo_ownership(client: AsyncClient) -> None:
    """소유권 행 생성은 사진 인증의 전제다 — 공용 헬퍼로 리팩터링해도 유지돼야 한다."""
    from sqlalchemy import select

    from app.core.database import AsyncSessionLocal
    from app.uploads.models import UploadedPhoto

    headers = await auth_headers(client)
    response = await client.post(
        "/api/v1/uploads/photo",
        files={"file": ("visit.png", _PNG_BYTES, "image/png")},
        headers=headers,
    )
    assert response.status_code == 201
    photo_url = response.json()["data"]["photo_url"]

    async with AsyncSessionLocal() as session:
        owned = await session.scalar(
            select(UploadedPhoto.id).where(UploadedPhoto.photo_url == photo_url)
        )
    assert owned is not None


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
