from collections.abc import Sequence
from uuid import UUID

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.auth.models import User
from app.core.enums import DnaType
from app.trip_dna.models import TripQuestion, TripQuestionOption, TripReply


async def list_active_questions(session: AsyncSession) -> Sequence[TripQuestion]:
    """활성화된(Soft Delete되지 않은) 모든 질문과 선택지 목록을 조회합니다.

    질문은 sort_order 오름차순으로 정렬되며,
    N+1 문제 방지를 위해 selectinload를 사용해 선택지(options)를 Eager Loading합니다.
    -> 비동기 SQLAlchemy 환경에서는 기본적으로 관계형 데이터가 "지연 로딩" 설정
       만약 selectinload 없이 질문만 조회한 상태에서 API 응답 시 .options 에 접근하면
       에러 및 추가 쿼리가 나갈 수 있음
    """
    stmt = (
        select(TripQuestion)
        .where(TripQuestion.deleted_at.is_(None))
        .order_by(TripQuestion.sort_order.asc())
        .options(
            # 질문을 가져올 때 연관된 options(선택지) 리스트도 한 번의 쿼리로 가져옵니다.
            selectinload(TripQuestion.options.and_(TripQuestionOption.deleted_at.is_(None)))
        )
    )
    result = await session.execute(stmt)

    questions = result.scalars().all()

    # 선택지들도 sort_order 순서대로 정렬하여 반환하기 위해 파이썬 레벨에서 정렬을 보장합니다.
    for question in questions:
        question.options.sort(key=lambda opt: opt.sort_order)

    return questions


async def list_active_question_ids(session: AsyncSession) -> Sequence[UUID]:
    stmt = select(TripQuestion.id).where(TripQuestion.deleted_at.is_(None))
    return (await session.scalars(stmt)).all()


async def soft_delete_user_replies(session: AsyncSession, user_id: UUID) -> None:
    """사용자가 이전에 제출하여 활성화(deleted_at IS NULL)되어 있던 답변들을
    Soft Delete 처리합니다."""
    stmt = (
        update(TripReply)
        .where(TripReply.user_id == user_id, TripReply.deleted_at.is_(None))
        .values(deleted_at=func.now())
    )
    await session.execute(stmt)


async def save_user_replies(session: AsyncSession, replies: list[TripReply]) -> None:
    """새로운 설문 답변 목록을 데이터베이스에 일괄 저장합니다."""
    session.add_all(replies)


async def get_options_by_ids(
    session: AsyncSession, option_ids: list[UUID]
) -> Sequence[TripQuestionOption]:
    """선택된 선택지(options)들의 상세 가중치 점수를 조회하기 위해
    상세 엔티티들을 일괄 조회합니다."""
    stmt = select(TripQuestionOption).where(
        TripQuestionOption.id.in_(option_ids), TripQuestionOption.deleted_at.is_(None)
    )
    result = await session.execute(stmt)
    return result.scalars().all()


async def update_user_dna(session: AsyncSession, user: User, dna_type: DnaType) -> None:
    """User 테이블의 dna 컬럼 값을 최종 판정된 DnaType으로 갱신합니다."""
    user.dna = dna_type
    session.add(user)
