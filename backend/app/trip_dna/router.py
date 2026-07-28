import logging

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import CurrentUser
from app.core.database import get_session
from app.core.response import Envelope, success
from app.trip_dna import service
from app.trip_dna.schemas import DNAResultResponse, QuestionRead, RepliesSubmitRequest

logger = logging.getLogger(__name__)

# prefix를 "/trip_dna"로 지정하여 진입 경로를 묶습니다.
router = APIRouter(prefix="/trip_dna", tags=["trip_dna"])


@router.get(
    "/questions",
    response_model=Envelope[list[QuestionRead]],
    summary="여행 DNA 질문 및 선택지 목록 조회",
)
async def get_survey_questions(
    # TODO: 인증 정보 연동되면 current_user 주석 해제
    # current_user: CurrentUser,
    session: AsyncSession = Depends(get_session),
) -> Envelope[list[QuestionRead]]:
    """
    사용자가 온보딩 또는 재진단 시 진행할 여행 DNA 설문지 질문 목록과 선택지를 조회합니다.

    ### 🔒 인증 규칙
    - **Bearer Token 인증 필수**: `Authorization` 헤더에 유효한 JWT Access Token을
      동반해야 요청할 수 있습니다.

    ### 🛡️ 보안 필터링
    - 선택지가 가진 각 성향별 가중치 점수(`score_value`)와 `category` 정보는
      클라이언트 조작 방지를 위해 **보안상 응답 결과에서 제외**됩니다.
      (프론트엔드는 단순 선택지 ID와 노출용 텍스트만 수신함)

    ### 📌 정렬 순서
    - 질문과 선택지는 각각 DB에 설정된 `sort_order` 기준으로 정렬되어 반환됩니다.
    """
    # TODO: current_user 연동 시 사용자 식별자를 함께 남긴다.
    logger.info("[TRIP_DNA] Request questions")

    """설문용 질문 및 선택지 리스트를 조회합니다."""
    questions = await service.get_survey_questions(session)
    return success(questions)


@router.post(
    "/replies",
    response_model=Envelope[DNAResultResponse],
    status_code=201,
    summary="설문 답변 제출 및 여행 DNA 진단 완료",
)
async def submit_survey_replies(
    payload: RepliesSubmitRequest,
    current_user: CurrentUser,
    session: AsyncSession = Depends(get_session),
) -> Envelope[DNAResultResponse]:
    """사용자가 선택한 답변 목록을 제출받아 저장하고, 성향 점수를 계산하여
    최종 판정된 DNA 결과를 유저 정보에 기록합니다."""
    logger.info(f"[TRIP_DNA] Submit survey replies by User(id: {current_user.id})")

    result = await service.submit_survey_replies(session, current_user, payload.replies)
    return success(result)
