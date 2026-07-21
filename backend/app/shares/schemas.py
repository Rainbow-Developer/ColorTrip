from __future__ import annotations

import uuid
from datetime import datetime
from enum import StrEnum

from pydantic import BaseModel, ConfigDict, Field


class ShareStyle(StrEnum):
    MAP_AND_DNA = "MAP_AND_DNA"
    MAP = "MAP"
    DNA = "DNA"


class ShareCreateRequest(BaseModel):
    share_style: ShareStyle = Field(
        ..., description="공유 카드 스타일 (MAP_AND_DNA, MAP, DNA)"
    )


class ShareCreateResponse(BaseModel):
    share_code: str
    share_url: str
    share_style: str
    created_at: datetime


class ColoredRegionItem(BaseModel):
    id: uuid.UUID
    name: str
    area_code: str | None = None

    model_config = ConfigDict(from_attributes=True)


class ShareSummaryResponse(BaseModel):
    nickname: str | None = None
    profile_image: str | None = None
    dna_type: str | None = None
    dna_name: str | None = None
    completed_region_count: int
    total_region_count: int
    progress_percentage: int
    colored_regions: list[ColoredRegionItem]


class ShareReadResponse(BaseModel):
    share_code: str
    share_style: str
    owner_nickname: str | None = None
    owner_profile_image: str | None = None
    dna_type: str | None = None
    dna_name: str | None = None
    completed_region_count: int
    total_region_count: int
    progress_percentage: int
    colored_regions: list[ColoredRegionItem]
