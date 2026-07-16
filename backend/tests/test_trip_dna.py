from __future__ import annotations

import pytest
from httpx import AsyncClient

from app.core.database import AsyncSessionLocal
from app.trip_dna.models import TripQuestion, TripQuestionOption
from tests.helpers import auth_headers  # 인증 헤더를 만들어주는 헬퍼 임포트


@pytest.mark.asyncio
async def test_get_trip_dna_questions_empty(client: AsyncClient) -> None:
    """DB에 질문 데이터가 없을 때, 빈 목록을 성공적으로 반환하는지 테스트합니다."""
    # 로그인 인증 헤더 획득 및 주입
    headers = await auth_headers(client)
    response = await client.get("/api/v1/trip_dna/questions", headers=headers)

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
        q2 = TripQuestion(question="질문 2번 (두 번째 노출)", sort_order=2)
        q1 = TripQuestion(question="질문 1번 (첫 번째 노출)", sort_order=1)
        session.add_all([q2, q1])
        await session.flush()

        o1_2 = TripQuestionOption(
            question_id=q1.id,
            content="Q1 선택지 2",
            score_value={"healing": 2},
            category="healing",
            sort_order=2,
        )
        o1_1 = TripQuestionOption(
            question_id=q1.id,
            content="Q1 선택지 1",
            score_value={"nature": 3},
            category="nature",
            sort_order=1,
        )
        o2_1 = TripQuestionOption(
            question_id=q2.id,
            content="Q2 선택지 1",
            score_value={"food": 5},
            category="food",
            sort_order=1,
        )
        session.add_all([o1_2, o1_1, o2_1])
        await session.commit()

    # 2. 로그인 인증 헤더 획득 및 주입
    headers = await auth_headers(client)
    response = await client.get("/api/v1/trip_dna/questions", headers=headers)

    assert response.status_code == 200
    res_json = response.json()
    assert res_json["status"] == 200

    data = res_json["data"]
    assert len(data) == 2

    # 3. 정렬 순서 검증 (질문 sort_order 기준 오름차순)
    assert data[0]["question"] == "질문 1번 (첫 번째 노출)"
    assert data[1]["question"] == "질문 2번 (두 번째 노출)"

    # 선택지 정렬 순서 검증 (sort_order 기준 오름차순)
    q1_options = data[0]["options"]
    assert len(q1_options) == 2
    assert q1_options[0]["content"] == "Q1 선택지 1"
    assert q1_options[1]["content"] == "Q1 선택지 2"

    # 4. 보안 필터링 검증 (score_value와 category 정보 제외 확인)
    for q in data:
        for opt in q["options"]:
            assert "score_value" not in opt
            assert "category" not in opt


@pytest.mark.asyncio
async def test_submit_survey_replies_success_and_grading(client: AsyncClient) -> None:
    """답변을 제출했을 때 점수 합산, 동률 처리 우선순위 및 유저 대표 DNA 갱신 상태를 검증합니다."""
    # 1. 질문 4개 및 각각의 가중치가 있는 선택지 DB 생성
    async with AsyncSessionLocal() as session:
        questions = [TripQuestion(question=f"질문 {i}", sort_order=i) for i in range(1, 5)]
        session.add_all(questions)
        await session.flush()

        options = []
        # Q1: 힐링(healing)에 3점 가중치
        options.append(
            TripQuestionOption(
                question_id=questions[0].id,
                content="healing opt",
                score_value={"healing": 3},
                category="healing",
                sort_order=1,
            )
        )
        # Q2: 자연(nature)에 3점 가중치
        options.append(
            TripQuestionOption(
                question_id=questions[1].id,
                content="nature opt",
                score_value={"nature": 3},
                category="nature",
                sort_order=1,
            )
        )
        # Q3: 미식(food)에 3점 가중치
        options.append(
            TripQuestionOption(
                question_id=questions[2].id,
                content="food opt",
                score_value={"food": 3},
                category="food",
                sort_order=1,
            )
        )
        # Q4: 힐링(healing)에 3점 가중치
        options.append(
            TripQuestionOption(
                question_id=questions[3].id,
                content="healing opt 2",
                score_value={"healing": 3},
                category="healing",
                sort_order=1,
            )
        )

        session.add_all(options)
        await session.commit()

    # 2. 로그인 인증 헤더 획득
    headers = await auth_headers(client)

    # 3. 설문 답변 제출 API 페이로드 빌드 및 POST 요청
    payload = {
        "replies": [
            {"question_id": str(questions[i].id), "question_option_id": str(options[i].id)}
            for i in range(4)
        ]
    }
    response = await client.post("/api/v1/trip_dna/replies", json=payload, headers=headers)

    # 4. 검증
    # 점수 합산: healing=6점, nature=3점, food=3점, history=0점, activity=0점
    # 최종 결과: 힐링(healing)이 최고점이므로 대표 DNA는 healing이어야 합니다.
    assert response.status_code == 201
    res_json = response.json()
    assert res_json["code"] == "SUCCESS"

    data = res_json["data"]
    assert data["main_dna_type"] == "healing"
    assert data["scores"]["healing"] == 6
    assert data["scores"]["nature"] == 3
    assert data["scores"]["food"] == 3
    assert data["scores"]["history"] == 0


@pytest.mark.asyncio
async def test_submit_survey_replies_empty(client: AsyncClient) -> None:
    """빈 replies 목록을 제출했을 때 422 Unprocessable Entity 에러가 발생하는지 검증합니다."""
    headers = await auth_headers(client)
    payload = {"replies": []}
    response = await client.post("/api/v1/trip_dna/replies", json=payload, headers=headers)
    assert response.status_code == 422
    res_json = response.json()
    assert res_json["code"] == "VALIDATION_ERROR"
    assert res_json["message"] == "요청 값이 올바르지 않습니다."


@pytest.mark.asyncio
async def test_submit_survey_replies_duplicate_question(client: AsyncClient) -> None:
    """동일한 질문에 대해 중복된 답변을 제출했을 때 400 Bad Request 에러가 발생하는지 검증합니다."""
    async with AsyncSessionLocal() as session:
        q = TripQuestion(question="중복 테스트용 질문", sort_order=1)
        session.add(q)
        await session.flush()

        o1 = TripQuestionOption(
            question_id=q.id,
            content="opt 1",
            score_value={"healing": 3},
            category="healing",
            sort_order=1,
        )
        o2 = TripQuestionOption(
            question_id=q.id,
            content="opt 2",
            score_value={"nature": 3},
            category="nature",
            sort_order=2,
        )
        session.add_all([o1, o2])
        await session.commit()

    headers = await auth_headers(client)
    payload = {
        "replies": [
            {"question_id": str(q.id), "question_option_id": str(o1.id)},
            {"question_id": str(q.id), "question_option_id": str(o2.id)},
        ]
    }
    response = await client.post("/api/v1/trip_dna/replies", json=payload, headers=headers)
    assert response.status_code == 400
    res_json = response.json()
    assert res_json["message"] == "중복된 질문에 대한 답변이 존재합니다."


@pytest.mark.asyncio
async def test_submit_survey_replies_invalid_mapping(client: AsyncClient) -> None:
    """제출된 선택지(question_option_id)가 해당 질문(question_id)에 속하지 않을 때
    400 에러를 반환하는지 검증합니다."""
    async with AsyncSessionLocal() as session:
        q1 = TripQuestion(question="질문 1", sort_order=1)
        q2 = TripQuestion(question="질문 2", sort_order=2)
        session.add_all([q1, q2])
        await session.flush()

        o1 = TripQuestionOption(
            question_id=q1.id,
            content="Q1 선택지",
            score_value={"healing": 3},
            category="healing",
            sort_order=1,
        )
        o2 = TripQuestionOption(
            question_id=q2.id,
            content="Q2 선택지",
            score_value={"nature": 3},
            category="nature",
            sort_order=1,
        )
        session.add_all([o1, o2])
        await session.commit()

    headers = await auth_headers(client)
    payload = {"replies": [{"question_id": str(q1.id), "question_option_id": str(o2.id)}]}
    response = await client.post("/api/v1/trip_dna/replies", json=payload, headers=headers)
    assert response.status_code == 400
    res_json = response.json()
    assert res_json["message"] == "유효하지 않은 답변 조합입니다."
