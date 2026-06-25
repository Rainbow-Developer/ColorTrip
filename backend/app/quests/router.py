"""quests — API 라우터.

규약: docs/conventions/api-design.md (/api/v1 + 복수형 kebab, Offset page/size)
"""

from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.core.enums import Category
from app.core.response import Envelope, success
from app.quests import service
from app.quests.schemas import QuestDetail, QuestListData

router = APIRouter(prefix="/quests", tags=["quests"])


@router.get("")
async def list_quests(
    region_id: UUID | None = None,
    category: Category | None = None,
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
    session: AsyncSession = Depends(get_session),
) -> Envelope[QuestListData]:
    data = await service.list_quests(session, region_id, category, page, size)
    return success(data)


@router.get("/{quest_id}")
async def get_quest(
    quest_id: UUID,
    session: AsyncSession = Depends(get_session),
) -> Envelope[QuestDetail]:
    quest = await service.get_quest_detail(session, quest_id)
    return success(QuestDetail.model_validate(quest))
