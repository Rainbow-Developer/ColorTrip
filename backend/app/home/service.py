"""home — 비즈니스 로직 계층 (홈 DNA 지역 추천).

기능 스펙: docs/specs/040-home-region-recommendation/plan.md
모델 없는 조회 도메인이라 repository 없이 service에서 직접 집계한다(plan 의사결정 1).
"""

from collections.abc import Sequence
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.enums import Category, JourneyStatus
from app.core.exceptions import AppException, ErrorCode
from app.home.schemas import HomeRecommendationData, RecommendedQuestSummary, RecommendedRegion
from app.journeys.models import Journey
from app.quests.dna import get_user_primary_category
from app.quests.models import Quest
from app.regions.models import Region

# DNA 미판정 사용자에게 적용하는 기본 카테고리 (plan 요구사항)
DEFAULT_DNA_CATEGORY = Category.NATURE
# 배너에 노출할 대표 퀘스트 요약 개수 (plan 의사결정 3)
QUEST_SUMMARY_LIMIT = 3


async def get_home_recommendation(session: AsyncSession, user_id: UUID) -> HomeRecommendationData:
    """DNA 기반 추천 지역 1곳 + 대표 퀘스트 요약(최대 3개)을 계산한다.

    지역 선정 규칙(plan 요구사항):
    1. DNA 카테고리 퀘스트가 가장 많은 지역. 단, 완료 여정이 있는 지역은 후순위
       (완료 여정 없는 지역 중 최다 → 전부 완료 여정이 있으면 전체 중 최다).
    2. 동률이면 전체 퀘스트 수가 많은 지역 (그래도 같으면 지역명 오름차순).
    """
    dna = await get_user_primary_category(session, user_id) or DEFAULT_DNA_CATEGORY

    counted = await _count_quests_by_region(session, dna)
    if not counted:
        # 퀘스트가 하나도 없으면 추천할 지역이 없다 (FE는 정적 데이터로 폴백).
        raise AppException(ErrorCode.NOT_FOUND_ERROR, "추천할 지역이 없습니다.")

    completed_region_ids = await _completed_journey_region_ids(session, user_id)
    region = _pick_region(counted, completed_region_ids)

    # DNA 일치 우선 → 썸네일 보유 우선 → 등록순 (요약·대표 이미지가 같은 순서를 공유)
    quests = sorted(
        await _list_region_quests(session, region.id),
        key=lambda q: (q.category != dna.value, q.thumbnail_url is None, q.created_at, q.id),
    )
    image_url = next((q.thumbnail_url for q in quests if q.thumbnail_url), None)

    return HomeRecommendationData(
        region=RecommendedRegion(id=region.id, name=region.name, image_url=image_url),
        dna_category=dna,
        quests=[
            RecommendedQuestSummary.model_validate(quest) for quest in quests[:QUEST_SUMMARY_LIMIT]
        ],
    )


async def _count_quests_by_region(
    session: AsyncSession, dna: Category
) -> list[tuple[Region, int, int]]:
    """지역별 (전체 퀘스트 수, DNA 카테고리 퀘스트 수)를 집계한다.

    퀘스트가 없는 지역은 추천 대상이 아니므로 inner join으로 제외한다.
    """
    dna_count = func.count(Quest.id).filter(Quest.category == dna.value)
    stmt = (
        select(Region, func.count(Quest.id), dna_count)
        .join(Quest, Quest.region_id == Region.id)
        .where(Region.deleted_at.is_(None), Quest.deleted_at.is_(None))
        .group_by(Region.id)
    )
    rows = (await session.execute(stmt)).all()
    return [(region, total_count, dna_count) for region, total_count, dna_count in rows]


async def _completed_journey_region_ids(session: AsyncSession, user_id: UUID) -> set[UUID]:
    """완료 여정이 1개 이상 있는 지역 id 집합 (soft delete 제외)."""
    stmt = (
        select(Journey.region_id)
        .where(
            Journey.user_id == user_id,
            Journey.status == JourneyStatus.COMPLETED.value,
            Journey.deleted_at.is_(None),
        )
        .distinct()
    )
    return set((await session.execute(stmt)).scalars().all())


def _pick_region(counted: list[tuple[Region, int, int]], completed_region_ids: set[UUID]) -> Region:
    """완료 여정 없는 지역 우선 풀에서 DNA 퀘스트 최다 지역을 고른다."""
    fresh = [row for row in counted if row[0].id not in completed_region_ids]
    pool = fresh or counted
    region, _, _ = min(pool, key=lambda row: (-row[2], -row[1], row[0].name))
    return region


async def _list_region_quests(session: AsyncSession, region_id: UUID) -> Sequence[Quest]:
    stmt = select(Quest).where(Quest.region_id == region_id, Quest.deleted_at.is_(None))
    return (await session.execute(stmt)).scalars().all()
