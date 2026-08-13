"""사진 스토리지 추상화 — GCS(운영 기본) / 로컬 디스크(개발·테스트 폴백).

docs/specs/010-journey/plan.md 의사결정 3: GCS_UPLOAD_BUCKET이 설정되면 GCS,
아니면 로컬 디스크(UPLOAD_DIR)에 저장한다. 반환값은 클라이언트가 그대로 쓸 photo_url.
"""

import asyncio
from functools import lru_cache
from pathlib import Path
from typing import Protocol

from app.core.config import settings


class PhotoStorage(Protocol):
    async def save(self, object_name: str, content: bytes, content_type: str) -> str:
        """콘텐츠를 저장하고 접근 URL을 반환한다."""
        ...

    async def delete(self, object_name: str) -> None:
        """저장에 실패한 객체를 정리한다."""
        ...

    async def load(self, object_name: str) -> bytes:
        """저장된 객체를 읽는다 — 사진 인증이 저장본으로 비전 판정을 수행한다
        (docs/specs/050-quest-verification). 없거나 읽지 못하면 예외를 던진다."""
        ...


class LocalPhotoStorage:
    def __init__(self, base_dir: str) -> None:
        self._base = Path(base_dir)

    async def save(self, object_name: str, content: bytes, content_type: str) -> str:
        path = self._base / object_name
        path.parent.mkdir(parents=True, exist_ok=True)
        await asyncio.to_thread(path.write_bytes, content)
        return f"/uploads/{object_name}"

    async def delete(self, object_name: str) -> None:
        path = self._base / object_name
        await asyncio.to_thread(path.unlink, missing_ok=True)

    async def load(self, object_name: str) -> bytes:
        return await asyncio.to_thread((self._base / object_name).read_bytes)


class GCSPhotoStorage:
    def __init__(self, bucket_name: str) -> None:
        # 지연 import: 로컬 개발·테스트에서는 GCS 클라이언트를 요구하지 않는다.
        from google.cloud import storage

        self._bucket_name = bucket_name
        self._bucket = storage.Client().bucket(bucket_name)

    async def save(self, object_name: str, content: bytes, content_type: str) -> str:
        blob = self._bucket.blob(object_name)
        await asyncio.to_thread(blob.upload_from_string, content, content_type=content_type)
        # 공개 읽기 버킷을 전제로 public URL 반환(plan 의사결정 3 · IaC 후속).
        # 비공개 버킷 운영 시 signed URL 발급으로 교체해야 한다.
        return f"https://storage.googleapis.com/{self._bucket_name}/{object_name}"

    async def delete(self, object_name: str) -> None:
        await asyncio.to_thread(self._bucket.blob(object_name).delete)

    async def load(self, object_name: str) -> bytes:
        return await asyncio.to_thread(self._bucket.blob(object_name).download_as_bytes)


def object_name_from_url(photo_url: str | None) -> str | None:
    """photo_url을 스토리지 객체 이름으로 되돌린다 — save()가 만든 URL의 역변환.

    현재 설정의 스토리지가 만든 형태만 인정한다(로컬 `/uploads/{object}` / GCS 공개 URL).
    형태가 맞지 않으면 None — 호출부는 판정 불가로 다뤄 통과시키지 않는다.

    `users.profile_image`에는 Kakao CDN URL이 초기값으로 들어갈 수 있어, 프로필 이미지
    삭제 경로도 이 판정으로 "우리가 저장한 객체"만 걸러낸다 (080-profile-image).
    """
    if photo_url is None:
        return None
    if settings.gcs_upload_bucket:
        prefix = f"https://storage.googleapis.com/{settings.gcs_upload_bucket}/"
        if photo_url.startswith(prefix):
            return _safe_object_name(photo_url.removeprefix(prefix))
        return None
    if photo_url.startswith("/uploads/"):
        return _safe_object_name(photo_url.removeprefix("/uploads/"))
    return None


def _safe_object_name(object_name: str) -> str | None:
    """빈 이름과 상위 경로 탈출(`..`)을 거른다.

    DB 값이 오염돼도 스토리지 바깥을 읽거나 지우지 못하게 하는 최후 방어선이다.
    """
    if not object_name or ".." in object_name.split("/"):
        return None
    return object_name


@lru_cache(maxsize=1)
def get_photo_storage() -> PhotoStorage:
    """FastAPI 의존성. 설정에 따라 스토리지 구현을 선택한다(프로세스당 1회 생성)."""
    if settings.gcs_upload_bucket:
        return GCSPhotoStorage(settings.gcs_upload_bucket)
    return LocalPhotoStorage(settings.upload_dir)
