"""ORM 공통 Base와 공통 컬럼 믹스인.

규약: docs/conventions/database.md
- PK: UUID v7 (앱에서 uuid_utils.uuid7 생성)
- 공통 타임스탬프: created_at / updated_at / deleted_at (Soft Delete)
- 시간: KST 기준
"""

import uuid
from datetime import datetime
from zoneinfo import ZoneInfo

from sqlalchemy import DateTime
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
from uuid_utils import uuid7

KST = ZoneInfo("Asia/Seoul")


def now_kst() -> datetime:
    return datetime.now(KST)


def new_uuid7() -> uuid.UUID:
    """uuid_utils.uuid7()을 표준 uuid.UUID로 변환해 반환."""
    return uuid.UUID(bytes=bytes(uuid7().bytes))


class Base(DeclarativeBase):
    pass


class UUIDPKMixin:
    id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, default=new_uuid7
    )


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_kst)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=now_kst, onupdate=now_kst
    )
    deleted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True, default=None
    )
