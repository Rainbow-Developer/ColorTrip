"""journeys — API 입출력 스키마 (pydantic v2)."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from app.core.enums import Category, JourneyStatus, MissionType, ProgressStatus


class JourneyCreateRequest(BaseModel):
    region_id: UUID
    quest_ids: list[UUID] = Field(min_length=1)
    title: str | None = Field(default=None, max_length=100)


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
