from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict


class TimelineBase(BaseModel):
    event_type: str
    title: str | None = None
    occurred_at: datetime


class TimelineCreate(TimelineBase):
    user_id: uuid.UUID
    region_id: uuid.UUID | None = None
    quest_progress_id: uuid.UUID | None = None


class TimelineRead(BaseModel):
    id: uuid.UUID
    event_type: str
    title: str | None = None
    region_name: str | None = None  # 조인된 시·군 이름
    quest_id: uuid.UUID | None = None
    quest_client_key: str | None = None
    photo_url: str | None = None
    occurred_at: datetime

    model_config = ConfigDict(from_attributes=True)
