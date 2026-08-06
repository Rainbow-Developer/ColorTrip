"""regions — 비즈니스 로직 계층."""

from collections.abc import Sequence
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.quests.dna import get_user_primary_category
from app.regions import repository
from app.regions.models import Region
from app.regions.schemas import RegionRead, UnvisitedRegionItem, UnvisitedRegionListData


async def list_regions(session: AsyncSession) -> Sequence[Region]:
    return await repository.list_regions(session)


async def list_unvisited_recommendations(
    session: AsyncSession,
    user_id: UUID,
    page: int,
    size: int,
) -> UnvisitedRegionListData:
    applied = await get_user_primary_category(session, user_id)
    rows, total = await repository.list_unvisited_recommendations(
        session,
        user_id,
        applied.value if applied else None,
        page,
        size,
    )
    return UnvisitedRegionListData(
        items=[
            UnvisitedRegionItem(
                **RegionRead.model_validate(region).model_dump(),
                matching_quest_count=matching,
                available_quest_count=available,
            )
            for region, matching, available in rows
        ],
        applied_category=applied,
        page=page,
        size=size,
        total=total,
    )
