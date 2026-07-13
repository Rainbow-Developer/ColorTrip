"""maps — 데이터 접근 계층 (SQLAlchemy 2.0 async)."""

from collections.abc import Sequence
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.progress.models import MapProgress
from app.regions.models import Region


async def list_regions_with_progress(
    session: AsyncSession, user_id: UUID
) -> Sequence[tuple[Region, MapProgress | None]]:
    stmt = (
        select(Region, MapProgress)
        .outerjoin(
            MapProgress,
            (MapProgress.region_id == Region.id)
            & (MapProgress.user_id == user_id)
            & MapProgress.deleted_at.is_(None),
        )
        .where(Region.deleted_at.is_(None))
        .order_by(Region.name.asc())
    )
    result = await session.execute(stmt)
    return result.all()
