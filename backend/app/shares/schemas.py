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
    share_style: ShareStyle = Field(..., description="공유 카드 스타일 (MAP_AND_DNA, MAP, DNA)")


class ShareCreateResponse(BaseModel):
    share_code: str
    share_url: str
    share_style: str
    created_at: datetime


class ColoredRegionItem(BaseModel):
    id: uuid.UUID
    name: str
    area_code: str | None = None
    completed_journey_count: int = 0

    model_config = ConfigDict(from_attributes=True)


class ShareSummaryResponse(BaseModel):
    nickname: str | None = None
    dna_type: str | None = None
    dna_name: str | None = None
    completed_region_count: int
    total_region_count: int
    progress_percentage: int
    colored_regions: list[ColoredRegionItem]


class ShareReadResponse(BaseModel):
    """공개(무인증) 공유 카드 응답.

    소유자 프로필 이미지는 싣지 않는다. 이 endpoint는 공유 코드만 알면 누구나 호출할 수
    있고 스토리지도 공개 읽기를 전제하므로, 사용자가 올린 사진 URL을 노출하지 않는다
    (080-profile-image 의사결정 5).
    """

    share_code: str
    share_style: str
    owner_nickname: str | None = None
    dna_type: str | None = None
    dna_name: str | None = None
    completed_region_count: int
    total_region_count: int
    progress_percentage: int
    colored_regions: list[ColoredRegionItem]
