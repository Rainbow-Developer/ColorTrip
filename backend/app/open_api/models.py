"""open_api_keys — 지자체 등 외부 기관에 발급하는 오픈 API 서비스키.

테이블 설계: docs/specs/070-municipal-open-api/plan.md
원문 키는 발급 시 1회만 노출하고 DB에는 해시만 저장한다(refresh_token과 동일한 방식,
app/core/security.py의 hash_open_api_key 참고).
"""

from sqlalchemy import Boolean, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.base import Base, TimestampMixin, UUIDPKMixin


class OpenApiKey(UUIDPKMixin, TimestampMixin, Base):
    __tablename__ = "open_api_keys"
    __table_args__ = (UniqueConstraint("key_hash", name="uq_open_api_keys_key_hash"),)

    name: Mapped[str] = mapped_column(String(100))  # 발급 대상 이름, 예: "단양군청"
    key_hash: Mapped[str] = mapped_column(String(64))  # HMAC-SHA256 hex digest
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true")
