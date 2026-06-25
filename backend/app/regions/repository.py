"""regions — 데이터 접근 계층 (SQLAlchemy 2.0 async)."""

from collections.abc import Sequence

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.regions.models import Region


async def list_regions(session: AsyncSession) -> Sequence[Region]:
    """삭제되지 않은 지역을 name 오름차순으로 조회."""
    stmt = (
        select(Region)
        .where(Region.deleted_at.is_(None))
        .order_by(Region.name.asc())
    )
    result = await session.execute(stmt)
    return result.scalars().all()
