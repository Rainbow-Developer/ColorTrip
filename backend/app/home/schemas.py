"""home — API 입출력 스키마 (pydantic v2)."""

from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.core.enums import Category, MissionType


class RecommendedRegion(BaseModel):
    id: UUID
    name: str
    # 지역 대표 이미지 — 해당 지역 퀘스트의 썸네일에서 대표 1건 (없으면 None)
    image_url: str | None


class RecommendedQuestSummary(BaseModel):
    """배너에 노출할 대표 퀘스트 요약 (최대 3개)."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    title: str
    category: Category
    mission_type: MissionType
    thumbnail_url: str | None


class HomeRecommendationData(BaseModel):
    region: RecommendedRegion
    dna_category: Category  # 적용된 DNA 카테고리 (미판정이면 기본값 nature)
    quests: list[RecommendedQuestSummary]
