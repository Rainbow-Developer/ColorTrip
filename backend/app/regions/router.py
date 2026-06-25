"""regions — API 라우터.

규약: docs/conventions/api-design.md (Envelope 응답, /api/v1 prefix는 main에서 부여)
"""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.core.response import Envelope, success
from app.regions import service
from app.regions.schemas import RegionRead

router = APIRouter(prefix="/regions", tags=["regions"])


@router.get("")
async def list_regions(
    session: AsyncSession = Depends(get_session),
) -> Envelope[list[RegionRead]]:
    regions = await service.list_regions(session)
    return success([RegionRead.model_validate(region) for region in regions])
