"""journeys — API 입출력 스키마 (pydantic v2)."""

from datetime import date, datetime
from typing import Self
from uuid import UUID

from pydantic import BaseModel, Field, model_validator

from app.core.enums import Category, JourneyStatus, MissionType, ProgressStatus


class JourneyCreateRequest(BaseModel):
    region_id: UUID
    quest_ids: list[UUID] = Field(min_length=1)
    title: str | None = Field(default=None, max_length=100)
    start_date: date | None = None
    end_date: date | None = None

    @model_validator(mode="after")
    def _validate_date_order(self) -> Self:
        if self.start_date and self.end_date and self.end_date < self.start_date:
            raise ValueError("end_date는 start_date보다 빠를 수 없습니다.")
        return self


class JourneyQuestAddRequest(BaseModel):
    quest_id: UUID


class JourneyProgressSummary(BaseModel):
    completed: int
    total: int


class JourneyQuestItem(BaseModel):
    quest_id: UUID
    title: str
    category: Category
    mission_type: MissionType
    thumbnail_url: str | None
    sort_order: int
    progress_status: ProgressStatus | None  # None = 시작 전


class JourneyListItem(BaseModel):
    id: UUID
    region_id: UUID
    title: str | None
    start_date: date | None
    end_date: date | None
    status: JourneyStatus
    progress: JourneyProgressSummary
    created_at: datetime
    completed_at: datetime | None


class JourneyDetail(JourneyListItem):
    quests: list[JourneyQuestItem]


class JourneyListData(BaseModel):
    items: list[JourneyListItem]
    page: int
    size: int
    total: int
