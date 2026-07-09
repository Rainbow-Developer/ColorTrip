from collections.abc import Sequence
from sqlalchemy.ext.asyncio import AsyncSession

from app.survey import repository
from app.survey.models import TripQuestion


async def get_survey_questions(session: AsyncSession) -> Sequence[TripQuestion]:
    """사용자가 진행할 초기 설문의 질문 및 선택지 리스트를 조회합니다."""
    questions = await repository.list_active_questions(session)
    return questions