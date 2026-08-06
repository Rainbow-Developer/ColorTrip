"""regions — API 입출력 스키마 (pydantic v2)."""

from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.core.enums import Category


class RegionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    slug: str | None
    area_code: str | None
    center_lat: Decimal | None
    center_lng: Decimal | None


class UnvisitedRegionItem(RegionRead):
    matching_quest_count: int
    available_quest_count: int


class UnvisitedRegionListData(BaseModel):
    items: list[UnvisitedRegionItem]
    applied_category: Category | None
    page: int
    size: int
    total: int
