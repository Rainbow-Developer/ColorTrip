from __future__ import annotations

import pytest
from httpx import AsyncClient
from app.core.database import AsyncSessionLocal
from app.trip_dna.models import TripQuestion, TripQuestionOption


@pytest.mark.asyncio
async def test_get_trip_dna_questions_empty(client: AsyncClient) -> None:
    """DB에 질문 데이터가 없을 때, 빈 목록을 성공적으로 반환하는지 테스트합니다."""
    response = await client.get("/api/v1/trip_dna/questions")

    assert response.status_code == 200
    res_json = response.json()
    assert res_json["status"] == 200
    assert res_json["code"] == "SUCCESS"
    assert res_json["data"] == []


@pytest.mark.asyncio
async def test_get_trip_dna_questions_with_data_and_sorting(client: AsyncClient) -> None:
    """DB에 질문과 선택지가 존재할 때 정렬 순서와 보안 필터링이 올바르게 적용되는지 검증합니다."""
    # 1. 테스트용 데이터 준비
    async with AsyncSessionLocal() as session:
        # 질문 2개 생성 (sort_order가 뒤바뀌어 있음)
        q2 = TripQuestion(question="질문 2번 (두 번째 노출)", sort_order=2)
        q1 = TripQuestion(question="질문 1번 (첫 번째 노출)", sort_order=1)
        session.add_all([q2, q1])
        await session.flush()  # ID 확보를 위해 flush

        # 질문 1번에 대한 선택지 생성 (sort_order가 뒤바뀌어 있음)
        o1_2 = TripQuestionOption(
            question_id=q1.id,
            content="Q1 선택지 2",
            score_value={"힐링": 2},
            category="healing",
            sort_order=2,
        )
        o1_1 = TripQuestionOption(
            question_id=q1.id,
            content="Q1 선택지 1",
            score_value={"자연탐험": 3},
            category="nature",
            sort_order=1,
        )

        # 질문 2번에 대한 선택지 생성
        o2_1 = TripQuestionOption(
            question_id=q2.id,
            content="Q2 선택지 1",
            score_value={"미식": 5},
            category="food",
            sort_order=1,
        )
        session.add_all([o1_2, o1_1, o2_1])
        await session.commit()

    # 2. API 호출
    response = await client.get("/api/v1/trip_dna/questions")

    assert response.status_code == 200
    res_json = response.json()
    assert res_json["status"] == 200
    
    data = res_json["data"]
    assert len(data) == 2

    # 3. 정렬 순서 검증 (질문 sort_order 기준 오름차순)
    # q1 (sort_order=1) -> q2 (sort_order=2)
    assert data[0]["question"] == "질문 1번 (첫 번째 노출)"
    assert data[1]["question"] == "질문 2번 (두 번째 노출)"

    # 선택지 정렬 순서 검증 (sort_order 기준 오름차순)
    # q1의 선택지: o1_1 (sort_order=1) -> o1_2 (sort_order=2)
    q1_options = data[0]["options"]
    assert len(q1_options) == 2
    assert q1_options[0]["content"] == "Q1 선택지 1"
    assert q1_options[1]["content"] == "Q1 선택지 2"

    # 4. 보안 필터링 검증
    # OptionRead 스키마에 따르면 score_value와 category 정보는 반환되어서는 안 됩니다.
    for q in data:
        for opt in q["options"]:
            assert "score_value" not in opt
            assert "category" not in opt
