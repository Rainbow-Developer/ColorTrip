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

# 충북 시·군 → TourAPI(KorService2) sigunguCode (areaCode=33 기준, areaCode2로 확인 2026-07-17).
# 상세: docs/conventions/external-apis.md. center_lat/lng는 추후 매핑.
CHUNGBUK_REGIONS: Sequence[tuple[str, str]] = (
    ("청주시", "10"),
    ("충주시", "11"),
    ("제천시", "7"),
    ("보은군", "3"),
    ("옥천군", "5"),
    ("영동군", "4"),
    ("증평군", "12"),
    ("진천군", "8"),
    ("괴산군", "1"),
    ("음성군", "6"),
    ("단양군", "2"),
)


async def seed_regions(session: AsyncSession) -> int:
    """name 기준으로 없으면 insert, 있는데 area_code가 비어 있으면 채운다. 추가된 개수를 반환."""
    stmt = select(Region)
    result = await session.execute(stmt)
    existing = {region.name: region for region in result.scalars().all()}

    added = 0
    for name, sigungu_code in CHUNGBUK_REGIONS:
        region = existing.get(name)
        if region is None:
            # center_lat·lng: 추후
            session.add(Region(name=name, area_code=sigungu_code, center_lat=None, center_lng=None))
            added += 1
        elif region.area_code is None:
            region.area_code = sigungu_code

    return added


async def _main() -> None:
    async with AsyncSessionLocal() as session:
        added = await seed_regions(session)
        await session.commit()
        print(f"seeded {added} region(s)")


if __name__ == "__main__":
    asyncio.run(_main())
