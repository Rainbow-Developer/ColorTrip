"""maps — 비즈니스 로직 계층."""

from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.maps import repository
from app.maps.schemas import MapProgressRead


async def get_my_map(session: AsyncSession, user_id: UUID) -> list[MapProgressRead]:
    rows = await repository.list_regions_with_progress(session, user_id)
    # 채색 기준: 지역별 완료 여정 수 (docs/specs/055-journey-map-coloring/)
    journey_counts = await repository.count_completed_journeys_by_region(session, user_id)
    return [
        MapProgressRead(
            region_id=region.id,
            region_name=region.name,
            completed_count=progress.completed_count if progress else 0,
            completed_journey_count=journey_counts.get(region.id, 0),
            first_colored_at=progress.first_colored_at if progress else None,
        )
        for region, progress in rows
    ]
