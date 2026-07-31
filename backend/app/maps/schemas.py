"""maps — API 입출력 스키마 (pydantic v2)."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class MapProgressRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    region_id: UUID
    region_name: str
    completed_count: int
    # 지도 채색 기준 — 그 지역에서 완료한 여정 수 (docs/specs/035-journey-map-coloring/)
    completed_journey_count: int = 0
    first_colored_at: datetime | None
