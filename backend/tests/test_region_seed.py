"""표준 지역 시드의 안정 키 보정 테스트."""

from httpx import AsyncClient
from sqlalchemy import select

from app.core.database import AsyncSessionLocal
from app.regions.models import Region
from app.regions.seed import seed_regions


async def test_seed_regions_repairs_missing_slug(client: AsyncClient) -> None:
    _ = client

    async with AsyncSessionLocal() as session:
        danyang = (
            await session.execute(select(Region).where(Region.name == "단양군"))
        ).scalar_one()
        danyang.slug = None
        await session.commit()

    async with AsyncSessionLocal() as session:
        added = await seed_regions(session)
        await session.commit()

    async with AsyncSessionLocal() as session:
        repaired = (
            await session.execute(select(Region).where(Region.name == "단양군"))
        ).scalar_one()

    assert added == 0
    assert repaired.slug == "danyang"
