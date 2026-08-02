"""journeys — API 라우터.

규약: docs/conventions/api-design.md (/api/v1 + 복수형, Offset page/size)
모든 엔드포인트는 보호 API(Bearer 토큰).
"""

from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import CurrentUser
from app.core.database import get_session
from app.core.enums import JourneyStatus
from app.core.response import Envelope, success
from app.journeys import service
from app.journeys.schemas import (
    JourneyCreateRequest,
    JourneyDetail,
    JourneyListData,
    JourneyQuestAddRequest,
    JourneyQuestReplaceRequest,
)

router = APIRouter(prefix="/journeys", tags=["journeys"])


@router.post("", status_code=201)
async def create_journey(
    payload: JourneyCreateRequest,
    current_user: CurrentUser,
    session: AsyncSession = Depends(get_session),
) -> Envelope[JourneyDetail]:
    data = await service.create_journey(
        session,
        current_user.id,
        payload.region_id,
        payload.quest_ids,
        payload.title,
        payload.start_date,
        payload.end_date,
        payload.client_request_id,
    )
    return success(data, status=201, message="여정이 생성되었습니다.")


@router.get("")
async def list_journeys(
    current_user: CurrentUser,
    status: JourneyStatus | None = None,
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
    session: AsyncSession = Depends(get_session),
) -> Envelope[JourneyListData]:
    data = await service.list_journeys(session, current_user.id, status, page, size)
    return success(data)


@router.get("/{journey_id}")
async def get_journey(
    journey_id: UUID,
    current_user: CurrentUser,
    session: AsyncSession = Depends(get_session),
) -> Envelope[JourneyDetail]:
    data = await service.get_journey_detail(session, current_user.id, journey_id)
    return success(data)


@router.post("/{journey_id}/quests")
async def add_journey_quest(
    journey_id: UUID,
    payload: JourneyQuestAddRequest,
    current_user: CurrentUser,
    session: AsyncSession = Depends(get_session),
) -> Envelope[JourneyDetail]:
    data = await service.add_quest(session, current_user.id, journey_id, payload.quest_id)
    return success(data, message="퀘스트를 여정에 담았습니다.")


@router.put("/{journey_id}/quests")
async def replace_journey_quests(
    journey_id: UUID,
    payload: JourneyQuestReplaceRequest,
    current_user: CurrentUser,
    session: AsyncSession = Depends(get_session),
) -> Envelope[JourneyDetail]:
    data = await service.replace_quests(
        session,
        current_user.id,
        journey_id,
        payload.quest_ids,
    )
    return success(data, message="여정 퀘스트를 저장했습니다.")


@router.delete("/{journey_id}/quests/{quest_id}")
async def remove_journey_quest(
    journey_id: UUID,
    quest_id: UUID,
    current_user: CurrentUser,
    session: AsyncSession = Depends(get_session),
) -> Envelope[JourneyDetail]:
    data = await service.remove_quest(session, current_user.id, journey_id, quest_id)
    return success(data, message="퀘스트를 여정에서 뺐습니다.")
