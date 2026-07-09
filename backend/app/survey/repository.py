from collections.abc import Sequence
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.survey.models import TripQuestion


async def list_active_questions(session: AsyncSession) -> Sequence[TripQuestion]:
    """활성화된(Soft Delete되지 않은) 모든 질문과 선택지 목록을 조회합니다.

    질문은 sort_order 오름차순으로 정렬되며,
    N+1 문제 방지를 위해 selectinload를 사용해 선택지(options)를 Eager Loading합니다.
    -> 비동기 SQLAlchemy 환경에서는 기본적으로 관계형 데이터가 "지연 로딩" 설정
       만약 selectinload 없이 질문만 조회한 상태에서 API 응답 시 .options 에 접근하면 에러 및 추가 쿼리가 나갈 수 있음
    """
    stmt = (
        select(TripQuestion)
        .where(TripQuestion.deleted_at.is_(None))
        .order_by(TripQuestion.sort_order.asc())
        .options(
            # 질문을 가져올 때 연관된 options(선택지) 리스트도 한 번의 쿼리로 다 가져오도록 지정합니다.
            selectinload(TripQuestion.options)
        )
    )
    result = await session.execute(stmt)

    questions = result.scalars().all()

    # 선택지들도 sort_order 순서대로 정렬하여 반환하기 위해 파이썬 레벨에서 정렬을 보장합니다.
    for question in questions:
        question.options.sort(key=lambda opt: opt.sort_order)

    return questions