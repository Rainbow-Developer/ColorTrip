"""quests — 비즈니스 로직 계층."""

from __future__ import annotations

from uuid import UUID

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.base import now_kst
from app.core.enums import Category, MissionType, ProgressStatus
from app.core.exceptions import AppException, ErrorCode
from app.journeys import repository as journeys_repository
from app.journeys import service as journeys_service
from app.quests import repository, verification
from app.quests.dna import get_user_primary_category
from app.quests.models import Quest, QuestProgress
from app.quests.schemas import (
    ProgressItem,
    ProgressListData,
    ProgressListItem,
    QuestListData,
    QuestListItem,
    QuestVerifyRequest,
    RecommendedListData,
    RecommendedQuestItem,
    VerifyResultData,
)
from app.timeline.service import handle_quest_completion


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


async def list_recommended(
    session: AsyncSession,
    user_id: UUID,
    region_id: UUID | None,
    category: Category | None,
    page: int,
    size: int,
) -> RecommendedListData:
    """DNA 기반 추천 — 완료 퀘스트 제외, 적용 카테고리 일치 항목 우선 정렬 (룰 기반).

    적용 카테고리 = `category` 파라미터 > 사용자 DNA(seam) > 없음(정렬 없이 반환).
    """
    applied = category or await get_user_primary_category(session, user_id)
    items, total = await repository.list_recommended(
        session, user_id, region_id, applied.value if applied else None, page, size
    )
    return RecommendedListData(
        items=[
            RecommendedQuestItem(
                **QuestListItem.model_validate(item).model_dump(),
                is_dna_match=applied is not None and item.category == applied.value,
            )
            for item in items
        ],
        applied_category=applied,
        page=page,
        size=size,
        total=total,
    )


async def start_quest(
    session: AsyncSession, user_id: UUID, quest_id: UUID, journey_id: UUID | None
) -> ProgressItem:
    """퀘스트 진행을 생성한다. 이미 진행 중이면 그대로 반환(멱등), 완료면 409."""
    quest = await _get_quest_or_404(session, quest_id)
    await _validate_journey_link(session, user_id, quest.id, journey_id)

    progress = await repository.get_progress(session, user_id, quest_id)
    if progress is not None:
        if progress.status == ProgressStatus.COMPLETED.value:
            raise AppException(ErrorCode.CONFLICT_ERROR, "이미 완료한 퀘스트입니다.")
        if journey_id is not None and progress.journey_id != journey_id:
            progress.journey_id = journey_id
            await session.commit()
        return ProgressItem.model_validate(progress)

    progress = QuestProgress(user_id=user_id, quest_id=quest_id, journey_id=journey_id)
    session.add(progress)
    try:
        await session.commit()
    except IntegrityError:
        # 동시 중복 요청: 유니크 제약 위반 → 먼저 생성된 진행을 읽어 그대로 반환(멱등).
        await session.rollback()
        existing = await repository.get_progress(session, user_id, quest_id)
        if existing is None:
            raise
        return ProgressItem.model_validate(existing)
    return ProgressItem.model_validate(progress)


async def verify_quest(
    session: AsyncSession, user_id: UUID, quest_id: UUID, payload: QuestVerifyRequest
) -> VerifyResultData:
    """미션 타입별 룰 기반 인증. 성공 시 완료 처리하고 관련 여정 상태를 갱신한다."""
    quest = await _get_quest_or_404(session, quest_id)
    await _validate_journey_link(session, user_id, quest.id, payload.journey_id)

    progress = await repository.get_progress(session, user_id, quest_id)
    if progress is not None and progress.status == ProgressStatus.COMPLETED.value:
        raise AppException(ErrorCode.CONFLICT_ERROR, "이미 완료한 퀘스트입니다.")

    verified, reason = verification.judge(
        quest,
        lat=payload.lat,
        lng=payload.lng,
        photo_url=payload.photo_url,
        answer=payload.answer,
    )

    if progress is None:  # start 없이 바로 인증하는 경우 진행을 함께 생성
        progress = QuestProgress(user_id=user_id, quest_id=quest_id, journey_id=payload.journey_id)
        session.add(progress)
    elif payload.journey_id is not None:
        progress.journey_id = payload.journey_id

    if quest.mission_type == MissionType.QUIZ.value:
        progress.quiz_answer = payload.answer
    else:
        progress.verified_lat = payload.lat
        progress.verified_lng = payload.lng
        progress.photo_url = payload.photo_url

    if verified:
        progress.status = ProgressStatus.COMPLETED.value
        progress.completed_at = now_kst()

    try:
        await session.flush()
        if verified:
            # 이 퀘스트를 담은 모든 내 여정의 완료 상태를 재계산한다.
            for journey in await journeys_repository.list_journeys_containing_quest(
                session, user_id, quest_id
            ):
                await journeys_service.recalculate_status(session, journey)
            # 타임라인 및 지도 색칠 처리 연동
            await handle_quest_completion(session, user_id, quest_id, progress.id)
        await session.commit()
    except IntegrityError:
        # 동시 중복 요청(진행이 없던 상태에서 병렬 인증): 먼저 만들어진 진행 결과를 반환.
        await session.rollback()
        existing = await repository.get_progress(session, user_id, quest_id)
        if existing is None:
            raise
        already_done = existing.status == ProgressStatus.COMPLETED.value
        return VerifyResultData(
            verified=already_done,
            reason=None if already_done else reason,
            progress=ProgressItem.model_validate(existing),
        )

    return VerifyResultData(
        verified=verified, reason=reason, progress=ProgressItem.model_validate(progress)
    )


async def list_my_progress(
    session: AsyncSession,
    user_id: UUID,
    status: ProgressStatus | None,
    page: int,
    size: int,
) -> ProgressListData:
    items, total = await repository.list_progress(
        session, user_id, status.value if status else None, page, size
    )
    return ProgressListData(
        items=[
            ProgressListItem(
                **ProgressItem.model_validate(item).model_dump(),
                quest_title=item.quest.title,
                quest_category=Category(item.quest.category),
                quest_thumbnail_url=item.quest.thumbnail_url,
            )
            for item in items
        ],
        page=page,
        size=size,
        total=total,
    )


async def _get_quest_or_404(session: AsyncSession, quest_id: UUID) -> Quest:
    quest = await repository.get_quest(session, quest_id)
    if quest is None:
        raise AppException(ErrorCode.NOT_FOUND_ERROR, "퀘스트를 찾을 수 없습니다.")
    return quest


async def _validate_journey_link(
    session: AsyncSession, user_id: UUID, quest_id: UUID, journey_id: UUID | None
) -> None:
    """journey_id가 오면 본인 여정이고 그 여정에 담긴 퀘스트인지 확인한다."""
    if journey_id is None:
        return
    journey = await journeys_repository.get_journey(session, journey_id, user_id)
    if journey is None:
        raise AppException(ErrorCode.NOT_FOUND_ERROR, "여정을 찾을 수 없습니다.")
    link = await journeys_repository.get_journey_quest(session, journey_id, quest_id)
    if link is None or link.deleted_at is not None:
        raise AppException(ErrorCode.VALIDATION_ERROR, "여정에 담기지 않은 퀘스트입니다.")
