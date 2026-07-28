"""regions — API 입출력 스키마 (pydantic v2)."""

from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class RegionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    slug: str
    area_code: str | None
    center_lat: Decimal | None
    center_lng: Decimal | None
