"""TourAPI 관광지를 Quest로 적재하는 로더.

규약: docs/conventions/external-apis.md (TourAPI)

`load_quests_for_region`는 지역의 area_code로 areaBasedList2를 호출해
받은 관광지를 Quest로 매핑·insert한다. 같은 content_id가 이미 있으면 skip한다.
"""

import asyncio
import logging
from decimal import Decimal, InvalidOperation

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import AsyncSessionLocal
from app.core.enums import Category, MissionType
from app.integrations.tour_api.client import TourApiClient
from app.quests.models import Quest
from app.regions.models import Region
from app.regions.repository import list_regions

logger = logging.getLogger(__name__)


def _to_decimal(value: object) -> Decimal | None:
    """좌표 문자열을 Decimal로 변환한다(값이 없거나 파싱 실패 시 None)."""
    if value is None or value == "":
        return None
    try:
        return Decimal(str(value))
    except (InvalidOperation, ValueError):
        return None


async def load_quests_for_region(session: AsyncSession, region: Region) -> int:
    """region의 관광지를 Quest로 적재하고 적재 건수를 반환한다.

    area_code가 없거나 TourAPI 키가 없으면 0을 반환한다.
    같은 content_id가 이미 있으면 skip한다.
    """
    if not region.area_code:
        logger.warning("region '%s'에 area_code가 없어 적재를 건너뜁니다.", region.name)
        return 0

    async with TourApiClient() as client:
        items = await client.fetch_area_based(region.area_code)

    if not items:
        return 0

    # 이미 적재된 content_id 집합 (중복 insert 방지)
    stmt = select(Quest.content_id).where(Quest.region_id == region.id)
    result = await session.execute(stmt)
    existing_content_ids = {cid for cid in result.scalars().all() if cid is not None}

    loaded = 0
    for item in items:
        content_id = item.get("contentid")
        if not content_id or content_id in existing_content_ids:
            continue

        session.add(
            Quest(
                region_id=region.id,
                title=item.get("title", ""),
                # TODO: 분류코드(cat1/2/3) → Category 매핑
                category=Category.NATURE.value,
                mission_type=MissionType.GPS_PHOTO.value,
                content_id=content_id,
                content_type_id=item.get("contenttypeid"),
                lat=_to_decimal(item.get("mapy")),
                lng=_to_decimal(item.get("mapx")),
                thumbnail_url=item.get("firstimage") or None,
            )
        )
        existing_content_ids.add(content_id)
        loaded += 1

    return loaded


async def _main() -> None:
    """전체 region을 순회하며 퀘스트를 적재하는 시드 골격."""
    async with AsyncSessionLocal() as session:
        regions = await list_regions(session)
        total = 0
        for region in regions:
            count = await load_quests_for_region(session, region)
            total += count
            print(f"{region.name}: {count} quest(s)")
        await session.commit()
        print(f"loaded {total} quest(s) total")


if __name__ == "__main__":
    asyncio.run(_main())
