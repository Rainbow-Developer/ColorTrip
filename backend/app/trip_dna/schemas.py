from uuid import UUID
from pydantic import BaseModel, ConfigDict


class OptionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    content: str
    sort_order: int


class QuestionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    # ConfigDict(from_attributes=True)
    # 설정 시, SQLAlchemy 객체(ORM 모델)를 Pydantic 객체로 변환했을 때 (ex.QuestionRead.model_validate(db_question))
    # 수동으로 딕셔너리로 풀지 않아도 자동으로 필드 값 읽어서 검증하고 변환

    id: UUID
    question: str
    sort_order: int
    options: list[OptionRead]  # 질문 하나에 여러 선택지가 리스트 형태로 귀속됩니다.

class ReplySubmitItem(BaseModel):
    question_id: UUID
    question_option_id: UUID

class RepliesSubmitRequest(BaseModel):
    replies: list[ReplySubmitItem]

class DNAResultResponse(BaseModel):
    user_id: UUID
    main_dna_type: str
    scores: dict[str, int]