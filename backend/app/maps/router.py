"""maps — API 라우터.

규약: docs/conventions/api-design.md (Envelope 응답, /api/v1 prefix는 main에서 부여)
"""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import CurrentUser
from app.core.database import get_session
from app.core.response import Envelope, success
from app.maps import service
from app.maps.schemas import MapProgressRead

router = APIRouter(prefix="/users", tags=["maps"])


@router.get("/me/map")
async def get_my_map(
    current_user: CurrentUser,
    session: AsyncSession = Depends(get_session),
) -> Envelope[list[MapProgressRead]]:
    data = await service.get_my_map(session, user_id=current_user.id)
    return success(data)
