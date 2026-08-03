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


@lru_cache(maxsize=1)
def get_photo_storage() -> PhotoStorage:
    """FastAPI 의존성. 설정에 따라 스토리지 구현을 선택한다(프로세스당 1회 생성)."""
    if settings.gcs_upload_bucket:
        return GCSPhotoStorage(settings.gcs_upload_bucket)
    return LocalPhotoStorage(settings.upload_dir)
