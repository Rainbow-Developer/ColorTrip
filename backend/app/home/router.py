"""home — API 라우터 (홈 DNA 지역 추천).

규약: docs/conventions/api-design.md (Envelope 응답, /api/v1 prefix는 main에서 부여)
기능 스펙: docs/specs/040-home-region-recommendation/
"""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import CurrentUser
from app.core.database import get_session
from app.core.response import Envelope, success
from app.home import service
from app.home.schemas import HomeRecommendationData

router = APIRouter(prefix="/home", tags=["home"])


@router.get("/recommendation")
async def get_home_recommendation(
    current_user: CurrentUser,
    session: AsyncSession = Depends(get_session),
) -> Envelope[HomeRecommendationData]:
    data = await service.get_home_recommendation(session, user_id=current_user.id)
    return success(data)
