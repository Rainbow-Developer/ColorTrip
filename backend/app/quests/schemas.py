"""quests — API 입출력 스키마 (pydantic v2)."""

from datetime import datetime
from decimal import Decimal
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.core.enums import Category, MissionType, ProgressStatus


class QuestListItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    region_id: UUID
    client_key: str
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


class RecommendedQuestItem(QuestListItem):
    is_dna_match: bool  # 적용된 DNA 카테고리와 일치 여부


class RecommendedListData(BaseModel):
    items: list[RecommendedQuestItem]
    applied_category: Category | None  # 추천에 적용된 카테고리 (DNA 또는 파라미터, 없으면 None)
    page: int
    size: int
    total: int


class QuestStartRequest(BaseModel):
    journey_id: UUID | None = None


class QuestVerifyRequest(BaseModel):
    journey_id: UUID | None = None
    # gps_photo
    lat: Decimal | None = None
    lng: Decimal | None = None
    photo_url: str | None = None
    # quiz
    answer: str | None = None
    # qr — 현장 QR 스캔 페이로드 (docs/specs/050-quest-verification/)
    qr_payload: str | None = None


class ProgressItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    quest_id: UUID
    journey_id: UUID | None
    status: ProgressStatus
    photo_url: str | None
    completed_at: datetime | None
    created_at: datetime


class ProgressListItem(ProgressItem):
    quest_title: str
    quest_category: Category
    quest_thumbnail_url: str | None


class VerifyResultData(BaseModel):
    verified: bool
    reason: str | None  # 실패 사유 (성공 시 None)
    progress: ProgressItem


class ProgressListData(BaseModel):
    items: list[ProgressListItem]
    page: int
    size: int
    total: int
