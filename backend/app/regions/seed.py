"""regions — 충북 11개 시·군 시드.

규약: docs/conventions/database.md (시드 / 더미 데이터)
실행: uv run python -m app.regions.seed
"""

import asyncio
from collections.abc import Sequence

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import AsyncSessionLocal
from app.quests.models import Quest  # noqa: F401  (Region.quests 관계 매퍼 해소용)
from app.regions.models import Region

# 충북 시·군 (area_code=TourAPI sigunguCode, center_lat/lng는 추후 매핑)
CHUNGBUK_REGIONS: Sequence[str] = (
    "청주시",
    "충주시",
    "제천시",
    "보은군",
    "옥천군",
    "영동군",
    "증평군",
    "진천군",
    "괴산군",
    "음성군",
    "단양군",
)


async def seed_regions(session: AsyncSession) -> int:
    """name 기준으로 이미 있으면 skip, 없으면 insert. 추가된 개수를 반환."""
    stmt = select(Region.name)
    result = await session.execute(stmt)
    existing = set(result.scalars().all())

    added = 0
    for name in CHUNGBUK_REGIONS:
        if name in existing:
            continue
        # area_code: TourAPI sigunguCode 추후 매핑 / center_lat·lng: 추후
        session.add(Region(name=name, area_code=None, center_lat=None, center_lng=None))
        added += 1

    return added


async def _main() -> None:
    async with AsyncSessionLocal() as session:
        added = await seed_regions(session)
        await session.commit()
        print(f"seeded {added} region(s)")


if __name__ == "__main__":
    asyncio.run(_main())
