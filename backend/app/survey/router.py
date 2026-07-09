import logging

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import CurrentUser
from app.core.database import get_session
from app.core.response import Envelope, success
from app.survey import service
from app.survey.schemas import QuestionRead

logger = logging.getLogger(__name__)

# prefix를 "/survey"로 지정하여 진입 경로를 묶습니다.
router = APIRouter(prefix="/survey", tags=["survey"])

@router.get(
    "/questions",
    response_model=Envelope[list[QuestionRead]],
    summary = "여행 DNA 질문 및 선택지 목록 조회"
)
async def get_survey_questions(
    # current_user: CurrentUser,
    session: AsyncSession = Depends(get_session),
) -> Envelope[list[QuestionRead]]:
    """
    사용자가 온보딩 또는 재진단 시 진행할 여행 DNA 설문지 질문 목록과 선택지를 조회합니다.

    ### 🔒 인증 규칙
    - **Bearer Token 인증 필수**: `Authorization` 헤더에 유효한 JWT Access Token을 동반해야 요청할 수 있습니다.

    ### 🛡️ 보안 필터링
    - 선택지가 가진 각 성향별 가중치 점수(`score_value`)와 `category` 정보는 클라이언트 조작 방지를 위해 **보안상 응답 결과에서 제외**됩니다.
      (프론트엔드는 단순 선택지 ID와 노출용 텍스트만 수신함)

    ### 📌 정렬 순서
    - 질문과 선택지는 각각 DB에 설정된 `sort_order` 기준으로 정렬되어 반환됩니다.
    """
    logger.info(f"[SURVEY] Request questions (User: current_user.id - current_user.username)")

    """설문용 질문 및 선택지 리스트를 조회합니다."""
    questions = await service.get_survey_questions(session)
    return success(questions)