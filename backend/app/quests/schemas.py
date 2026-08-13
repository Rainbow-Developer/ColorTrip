"""quests — API 입출력 스키마 (pydantic v2)."""

from datetime import datetime
from decimal import Decimal
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.core.enums import Category, MissionType, ProgressStatus
from app.integrations.vision.base import VisionVerdict


class QuestListItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    region_id: UUID
    client_key: str | None
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
    # gps / gps_photo
    lat: Decimal | None = None
    lng: Decimal | None = None
    # photo / gps_photo — 업로드 API가 돌려준 URL (길이 상한은 저장 컬럼과 맞춘다)
    photo_url: str | None = Field(default=None, max_length=500)
    # quiz
    answer: str | None = Field(default=None, max_length=200)
    # qr — 현장 QR 스캔 페이로드 (docs/specs/050-quest-verification/).
    # 상한은 페이로드 형식(`colortrip:quest:{id}:{서명 16자}`) 기준 여유값 — 과대 입력을
    # 파싱 전에 막는다(판정 전용 엔드포인트에 있던 제약을 통합 경로로 옮김, KAN-73).
    qr_payload: str | None = Field(default=None, max_length=256)


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

    # 사진 미션(photo·gps_photo)의 비전 판정 상세 — 신뢰도·사유·판정 제공자.
    # 그 밖의 미션에서는 None (docs/specs/050-quest-verification).
    photo_verdict: VisionVerdict | None = None


class ProgressListData(BaseModel):
    items: list[ProgressListItem]
    page: int
    size: int
    total: int
