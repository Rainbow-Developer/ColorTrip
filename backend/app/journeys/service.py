"""journeys — 비즈니스 로직 계층.

여정 상태 규칙(docs/specs/010-journey/plan.md 의사결정 6):
모든 퀘스트가 완료되면 자동 completed, 미완료 퀘스트가 다시 생기면 in_progress로 복귀.
"""

from datetime import date
from uuid import UUID

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.base import now_kst
from app.core.enums import JourneyStatus, ProgressStatus
from app.core.exceptions import AppException, ErrorCode
from app.journeys import repository
from app.journeys.models import Journey, JourneyQuest
from app.journeys.schemas import (
    JourneyDetail,
    JourneyListData,
    JourneyListItem,
    JourneyProgressSummary,
    JourneyQuestItem,
)


async def create_journey(
    session: AsyncSession,
    user_id: UUID,
    region_id: UUID,
    quest_ids: list[UUID],
    title: str | None,
    start_date: date | None = None,
    end_date: date | None = None,
    client_request_id: UUID | None = None,
) -> JourneyDetail:
    if client_request_id is not None:
        existing = await repository.get_journey_by_client_request_id(
            session, user_id, client_request_id
        )
        if existing is not None:
            return await get_journey_detail(session, user_id, existing.id)

    unique_ids = list(dict.fromkeys(quest_ids))  # 중복 제거(순서 유지)
    quests = await repository.get_quests_by_ids(session, unique_ids)
    found = {quest.id for quest in quests}
    missing = [str(qid) for qid in unique_ids if qid not in found]
    if missing:
        raise AppException(ErrorCode.NOT_FOUND_ERROR, f"존재하지 않는 퀘스트: {', '.join(missing)}")

    outside = [quest for quest in quests if quest.region_id != region_id]
    if outside:
        raise AppException(
            ErrorCode.VALIDATION_ERROR, "여정 지역에 속하지 않는 퀘스트는 담을 수 없습니다."
        )

    journey = Journey(
        user_id=user_id,
        region_id=region_id,
        title=title,
        start_date=start_date,
        end_date=end_date,
        client_request_id=client_request_id,
    )
    session.add(journey)
    try:
        await session.flush()
        for order, quest_id in enumerate(unique_ids):
            session.add(JourneyQuest(journey_id=journey.id, quest_id=quest_id, sort_order=order))
        await session.flush()
        # 담은 퀘스트를 이미 완료한 사용자라면 생성 즉시 완료 상태가 되어야 한다.
        await recalculate_status(session, journey)
        await session.commit()
    except IntegrityError:
        await session.rollback()
        if client_request_id is None:
            raise
        existing = await repository.get_journey_by_client_request_id(
            session, user_id, client_request_id
        )
        if existing is None:
            raise
        return await get_journey_detail(session, user_id, existing.id)

    return await get_journey_detail(session, user_id, journey.id)


async def list_journeys(
    session: AsyncSession,
    user_id: UUID,
    status: JourneyStatus | None,
    page: int,
    size: int,
) -> JourneyListData:
    journeys, total = await repository.list_journeys(
        session, user_id, status.value if status else None, page, size
    )
    journey_ids = [journey.id for journey in journeys]
    summary = await repository.progress_summary_map(session, user_id, journey_ids)
    quest_keys: dict[UUID, list[str]] = {journey_id: [] for journey_id in journey_ids}
    for link in await repository.list_journey_quests_for_journeys(session, journey_ids):
        if link.quest.client_key is not None:
            quest_keys[link.journey_id].append(link.quest.client_key)
    items = [
        JourneyListItem(
            id=journey.id,
            region_id=journey.region_id,
            title=journey.title,
            start_date=journey.start_date,
            end_date=journey.end_date,
            status=JourneyStatus(journey.status),
            progress=_summary(summary.get(journey.id)),
            quest_client_keys=quest_keys[journey.id],
            created_at=journey.created_at,
            completed_at=journey.completed_at,
        )
        for journey in journeys
    ]
    return JourneyListData(items=items, page=page, size=size, total=total)


async def get_journey_detail(
    session: AsyncSession, user_id: UUID, journey_id: UUID
) -> JourneyDetail:
    journey = await _get_owned_journey(session, user_id, journey_id)
    journey_quests = await repository.list_journey_quests(session, journey_id)
    status_map = await repository.progress_status_map(
        session, user_id, [jq.quest_id for jq in journey_quests]
    )
    quests = [
        JourneyQuestItem(
            quest_id=jq.quest_id,
            client_key=jq.quest.client_key,
            title=jq.quest.title,
            category=jq.quest.category,  # type: ignore[arg-type]
            mission_type=jq.quest.mission_type,  # type: ignore[arg-type]
            thumbnail_url=jq.quest.thumbnail_url,
            sort_order=jq.sort_order,
            progress_status=_progress_status(status_map.get(jq.quest_id)),
        )
        for jq in journey_quests
    ]
    completed = sum(1 for q in quests if q.progress_status == ProgressStatus.COMPLETED)
    return JourneyDetail(
        id=journey.id,
        region_id=journey.region_id,
        title=journey.title,
        start_date=journey.start_date,
        end_date=journey.end_date,
        status=JourneyStatus(journey.status),
        progress=JourneyProgressSummary(completed=completed, total=len(quests)),
        quest_client_keys=[item.client_key for item in quests if item.client_key is not None],
        created_at=journey.created_at,
        completed_at=journey.completed_at,
        quests=quests,
    )


async def add_quest(
    session: AsyncSession, user_id: UUID, journey_id: UUID, quest_id: UUID
) -> JourneyDetail:
    journey = await _get_owned_journey(session, user_id, journey_id)

    quests = await repository.get_quests_by_ids(session, [quest_id])
    if not quests:
        raise AppException(ErrorCode.NOT_FOUND_ERROR, "퀘스트를 찾을 수 없습니다.")
    if quests[0].region_id != journey.region_id:
        raise AppException(
            ErrorCode.VALIDATION_ERROR, "여정 지역에 속하지 않는 퀘스트는 담을 수 없습니다."
        )

    existing = await repository.get_journey_quest(session, journey_id, quest_id)
    if existing is not None and existing.deleted_at is None:
        raise AppException(ErrorCode.CONFLICT_ERROR, "이미 여정에 담긴 퀘스트입니다.")

    next_order = await repository.max_sort_order(session, journey_id) + 1
    if existing is not None:  # 제거했던 퀘스트 복원
        existing.deleted_at = None
        existing.sort_order = next_order
    else:
        session.add(JourneyQuest(journey_id=journey_id, quest_id=quest_id, sort_order=next_order))
    await session.flush()
    await recalculate_status(session, journey)
    await session.commit()

    return await get_journey_detail(session, user_id, journey_id)


async def remove_quest(
    session: AsyncSession, user_id: UUID, journey_id: UUID, quest_id: UUID
) -> JourneyDetail:
    journey = await _get_owned_journey(session, user_id, journey_id)

    existing = await repository.get_journey_quest(session, journey_id, quest_id)
    if existing is None or existing.deleted_at is not None:
        raise AppException(ErrorCode.NOT_FOUND_ERROR, "여정에 없는 퀘스트입니다.")

    existing.deleted_at = now_kst()
    await session.flush()
    await recalculate_status(session, journey)
    await session.commit()

    return await get_journey_detail(session, user_id, journey_id)


async def replace_quests(
    session: AsyncSession,
    user_id: UUID,
    journey_id: UUID,
    quest_ids: list[UUID],
) -> JourneyDetail:
    journey = await repository.get_journey_for_update(session, journey_id, user_id)
    if journey is None:
        raise AppException(ErrorCode.NOT_FOUND_ERROR, "여정을 찾을 수 없습니다.")

    unique_ids = list(dict.fromkeys(quest_ids))
    quests = await repository.get_quests_by_ids(session, unique_ids)
    found = {quest.id for quest in quests}
    missing = [str(quest_id) for quest_id in unique_ids if quest_id not in found]
    if missing:
        raise AppException(
            ErrorCode.NOT_FOUND_ERROR,
            f"존재하지 않는 퀘스트: {', '.join(missing)}",
        )
    if any(quest.region_id != journey.region_id for quest in quests):
        raise AppException(
            ErrorCode.VALIDATION_ERROR,
            "여정 지역에 속하지 않는 퀘스트는 담을 수 없습니다.",
        )

    selected = set(unique_ids)
    links = {
        link.quest_id: link
        for link in await repository.list_all_journey_quests(session, journey_id)
    }
    removed_at = now_kst()
    for quest_id, link in links.items():
        if quest_id not in selected:
            link.deleted_at = removed_at

    for order, quest_id in enumerate(unique_ids):
        link = links.get(quest_id)
        if link is None:
            session.add(
                JourneyQuest(
                    journey_id=journey_id,
                    quest_id=quest_id,
                    sort_order=order,
                )
            )
        else:
            link.deleted_at = None
            link.sort_order = order

    await session.flush()
    await recalculate_status(session, journey)
    await session.commit()
    return await get_journey_detail(session, user_id, journey_id)


async def recalculate_status(session: AsyncSession, journey: Journey) -> None:
    """여정 퀘스트 완료 현황으로 status를 재계산한다 (호출자가 commit)."""
    summary = await repository.progress_summary_map(session, journey.user_id, [journey.id])
    completed, total = summary.get(journey.id, (0, 0))
    if total > 0 and completed == total:
        if journey.status != JourneyStatus.COMPLETED.value:
            journey.status = JourneyStatus.COMPLETED.value
            journey.completed_at = now_kst()
    elif journey.status != JourneyStatus.IN_PROGRESS.value:
        journey.status = JourneyStatus.IN_PROGRESS.value
        journey.completed_at = None


async def _get_owned_journey(session: AsyncSession, user_id: UUID, journey_id: UUID) -> Journey:
    journey = await repository.get_journey(session, journey_id, user_id)
    if journey is None:
        raise AppException(ErrorCode.NOT_FOUND_ERROR, "여정을 찾을 수 없습니다.")
    return journey


def _summary(value: tuple[int, int] | None) -> JourneyProgressSummary:
    completed, total = value or (0, 0)
    return JourneyProgressSummary(completed=completed, total=total)


def _progress_status(value: str | None) -> ProgressStatus | None:
    return ProgressStatus(value) if value else None
