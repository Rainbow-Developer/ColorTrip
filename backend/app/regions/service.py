"""regions — 비즈니스 로직 계층."""

from collections.abc import Sequence

from sqlalchemy.ext.asyncio import AsyncSession

from app.regions import repository
from app.regions.models import Region


async def list_regions(session: AsyncSession) -> Sequence[Region]:
    return await repository.list_regions(session)
