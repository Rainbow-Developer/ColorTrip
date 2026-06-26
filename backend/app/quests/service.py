"""quests — 비즈니스 로직 계층."""

from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AppException, ErrorCode
from app.quests import repository
from app.quests.models import Quest
from app.quests.schemas import QuestListData, QuestListItem


async def list_quests(
    session: AsyncSession,
    region_id: UUID | None,
    category: str | None,
    page: int,
    size: int,
) -> QuestListData:
    items, total = await repository.list_quests(session, region_id, category, page, size)
    return QuestListData(
        items=[QuestListItem.model_validate(item) for item in items],
        page=page,
        size=size,
        total=total,
    )


async def get_quest_detail(session: AsyncSession, quest_id: UUID) -> Quest:
    quest = await repository.get_quest(session, quest_id)
    if quest is None:
        raise AppException(ErrorCode.NOT_FOUND_ERROR)
    # TODO: content_id로 TourAPI 소개정보(운영정보) 연결 (의사결정 5)
    return quest
