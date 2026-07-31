from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.models import User
from app.core.enums import DnaType
from app.trip_dna import repository
from app.trip_dna.models import TripReply
from app.trip_dna.schemas import DNAResultResponse, QuestionRead, ReplySubmitItem

# 동률 점수 발생 시 우선순위 가중치 (낮을수록 더 높은 우선순위)
TIE_BREAKER_PRIORITY = {
    "nature": 0,
    "food": 1,
    "history": 2,
    "activity": 3,
    "healing": 4,
}


async def get_survey_questions(session: AsyncSession) -> list[QuestionRead]:
    """사용자가 진행할 초기 설문의 질문 및 선택지 리스트를 응답 스키마로 변환해 조회합니다."""
    questions = await repository.list_active_questions(session)
    return [QuestionRead.model_validate(question) for question in questions]


async def submit_survey_replies(
    session: AsyncSession, user: User, replies_data: list[ReplySubmitItem]
) -> DNAResultResponse:
    """사용자가 제출한 설문 답변을 기반으로 점수를 연산하고,
    이전 답변 Soft Delete 및 유저 대표 DNA 결과를 데이터베이스에 기록합니다.
    """
    # 중복 질문 제출 검증
    question_ids = [item.question_id for item in replies_data]
    if len(question_ids) != len(set(question_ids)):
        raise HTTPException(status_code=400, detail="중복된 질문에 대한 답변이 존재합니다.")

    option_ids = [item.question_option_id for item in replies_data]
    options = await repository.get_options_by_ids(session, option_ids)

    # question_id와 question_option_id 간 유효 매핑 검증
    option_map = {opt.id: opt for opt in options}
    for item in replies_data:
        option = option_map.get(item.question_option_id)
        if option is None or option.question_id != item.question_id:
            raise HTTPException(status_code=400, detail="유효하지 않은 답변 조합입니다.")

    # 1. 5대 카테고리 점수판 초기화 (eat -> food 변경)
    scores = {"nature": 0, "food": 0, "history": 0, "activity": 0, "healing": 0}

    # 2. 선택한 답변의 가중치 점수 합산
    for opt in options:
        opt_score = opt.score_value or {}
        for key in scores.keys():
            scores[key] += opt_score.get(key, 0)

    # 3. 대표 DNA 판정 및 동률 처리 (Tie-Breaking)
    best_score_key = max(scores.keys(), key=lambda k: (scores[k], -TIE_BREAKER_PRIORITY[k]))

    # 4. 문자열 키(best_score_key)를 그대로 DnaType Enum으로 직렬화
    main_dna_type = DnaType(best_score_key)

    # 5. 기존 사용자의 답변 목록 Soft Delete
    await repository.soft_delete_user_replies(session, user.id)

    # 6. 새로운 설문 답변 기록 객체 빌드 및 저장
    new_replies = [
        TripReply(
            user_id=user.id,
            question_id=item.question_id,
            question_option_id=item.question_option_id,
        )
        for item in replies_data
    ]

    await repository.save_user_replies(session, new_replies)

    # 7. User 테이블의 dna 컬럼 갱신
    await repository.update_user_dna(session, user, main_dna_type)

    # 8. 커밋 — get_session은 커밋하지 않으므로(app/core/database.py) 여기서 확정한다.
    #    없으면 응답은 정상인데 답변·User.dna가 저장되지 않아, DNA 기반 홈 추천
    #    (docs/specs/040-home-region-recommendation)이 항상 기본값으로 동작한다.
    await session.commit()

    return DNAResultResponse(user_id=user.id, main_dna_type=main_dna_type.value, scores=scores)
