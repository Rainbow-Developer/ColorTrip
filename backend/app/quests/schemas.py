"""quests — API 입출력 스키마 (pydantic v2)."""

from decimal import Decimal
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.core.enums import Category, MissionType


class QuestListItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    region_id: UUID
    title: str
    category: Category
    mission_type: MissionType
    lat: Decimal | None
    lng: Decimal | None
    thumbnail_url: str | None


class QuestDetail(QuestListItem):
    description: str | None
    content_id: str | None
    content_type_id: str | None
    verify_radius: int
    mission_meta: dict[str, Any] | None
    operation_info: dict | None = None  # 운영정보, 추후 tour_api 연결


class QuestListData(BaseModel):
    items: list[QuestListItem]
    page: int
    size: int
    total: int
