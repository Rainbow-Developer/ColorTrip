"""open_api — 지자체 오픈 API 통계 조립.

지역 단위 집계 응답만 만든다. 개인 식별 값은 절대 포함하지 않는다
(docs/specs/070-municipal-open-api/plan.md).
"""

from __future__ import annotations

from datetime import timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.base import now_kst
from app.core.exceptions import AppException, ErrorCode
from app.open_api import repository
from app.open_api.schemas import (
    JourneyCompletion,
    MonthlyCount,
    PopularSpot,
    RegionStatsResponse,
    RegionSummary,
    ShareStats,
    VisitStats,
)

_DAYS_PER_MONTH = 30  # 월별 집계 기간 산정용 근사치 — 달력월 경계까지 정밀하게 맞출 필요는 없다.


async def get_region_stats(
    session: AsyncSession, region_slug: str, months: int
) -> RegionStatsResponse:
    region = await repository.get_region_by_slug(session, region_slug)
    if region is None or region.slug is None:
        raise AppException(ErrorCode.NOT_FOUND_ERROR, "존재하지 않는 지역입니다.")

    since = now_kst() - timedelta(days=_DAYS_PER_MONTH * months)

    total_completed = await repository.count_completed_quests(session, region.id)
    monthly_rows = await repository.monthly_completed_quest_counts(session, region.id, since)
    popular_rows = await repository.top_popular_spots(session, region.id)
    verification_rows = await repository.verification_method_breakdown(session, region.id)
    dna_rows = await repository.dna_distribution(session, region.id)
    started, completed, avg_days = await repository.journey_completion_stats(session, region.id)
    share_rows = await repository.share_counts_by_style(session, region.id)

    verification_total = sum(count for _, count in verification_rows)
    dna_total = sum(count for _, count in dna_rows)

    return RegionStatsResponse(
        region=RegionSummary(id=region.id, name=region.name, slug=region.slug),
        visit_stats=VisitStats(
            total_completed_quests=total_completed,
            monthly=[MonthlyCount(month=month, count=count) for month, count in monthly_rows],
        ),
        popular_spots=[
            PopularSpot(quest_id=quest_id, title=title, completed_count=count)
            for quest_id, title, count in popular_rows
        ],
        dna_distribution={dna: count / dna_total for dna, count in dna_rows if dna_total > 0},
        journey_completion=JourneyCompletion(
            started=started,
            completed=completed,
            completion_rate=(completed / started) if started > 0 else 0.0,
            avg_days_to_complete=avg_days,
        ),
        verification_method_breakdown={
            method: count / verification_total
            for method, count in verification_rows
            if verification_total > 0
        },
        share_stats=ShareStats(
            total_shares=sum(count for _, count in share_rows),
            by_style=dict(share_rows),
        ),
    )
