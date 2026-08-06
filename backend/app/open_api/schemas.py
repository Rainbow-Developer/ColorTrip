from __future__ import annotations

import uuid

from pydantic import BaseModel


class RegionSummary(BaseModel):
    id: uuid.UUID
    name: str
    slug: str


class MonthlyCount(BaseModel):
    month: str  # "2026-07"
    count: int


class VisitStats(BaseModel):
    total_completed_quests: int
    monthly: list[MonthlyCount]


class PopularSpot(BaseModel):
    quest_id: uuid.UUID
    title: str
    completed_count: int


class JourneyCompletion(BaseModel):
    started: int
    completed: int
    completion_rate: float
    avg_days_to_complete: float | None


class ShareStats(BaseModel):
    total_shares: int
    by_style: dict[str, int]


class RegionStatsResponse(BaseModel):
    region: RegionSummary
    visit_stats: VisitStats
    popular_spots: list[PopularSpot]
    dna_distribution: dict[str, float]
    journey_completion: JourneyCompletion
    verification_method_breakdown: dict[str, float]
    share_stats: ShareStats
