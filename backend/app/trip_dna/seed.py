"""survey — 여행 DNA 초기 질문지 데이터 시드.

실행: uv run python -m app.trip_dna.seed [--reset]
"""

import asyncio
import sys
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import AsyncSessionLocal
from app.trip_dna.models import TripQuestion, TripQuestionOption


async def seed_survey(session: AsyncSession, reset: bool = False) -> None:
    if reset:
        print("Resetting survey tables...")
        await session.execute(delete(TripQuestionOption))
        await session.execute(delete(TripQuestion))
        await session.flush()

    questions_data = [
        {
            "question": "여행 계획을 세울 때 내가 가장 먼저 찾아보는 것은?",
            "sort_order": 1,
            "options": [
                {
                    "content": "SNS에서 핫한 포토스팟과 아름다운 풍경",
                    "category": "nature",
                    "score_value": {"nature": 3, "eat": 0, "history": 0, "activity": 1, "healing": 1},
                    "sort_order": 1,
                },
                {
                    "content": "그 지역의 맛집과 유명한 디저트 카페",
                    "category": "food",
                    "score_value": {"nature": 0, "eat": 3, "history": 0, "activity": 0, "healing": 1},
                    "sort_order": 2,
                },
                {
                    "content": "박물관, 미술관이나 역사적인 유적지",
                    "category": "history",
                    "score_value": {"nature": 1, "eat": 0, "history": 3, "activity": 0, "healing": 0},
                    "sort_order": 3,
                },
                {
                    "content": "루지, 서핑, 짚라인 등 재미있는 레포츠 활동",
                    "category": "activity",
                    "score_value": {"nature": 1, "eat": 0, "history": 0, "activity": 3, "healing": 0},
                    "sort_order": 4,
                },
            ],
        },
        {
            "question": "여행지에서 아침에 일어났을 때 내가 하고 싶은 일은?",
            "sort_order": 2,
            "options": [
                {
                    "content": "일찍 일어나서 가볍게 상쾌한 공기 마시며 산책하기",
                    "category": "nature",
                    "score_value": {"nature": 3, "eat": 0, "history": 0, "activity": 0, "healing": 2},
                    "sort_order": 1,
                },
                {
                    "content": "늦잠 푹 자고 일어나서 여유롭게 브런치 먹으러 가기",
                    "category": "food",
                    "score_value": {"nature": 0, "eat": 3, "history": 0, "activity": 0, "healing": 2},
                    "sort_order": 2,
                },
                {
                    "content": "지역에서 가장 오래된 고즈넉한 사찰 방문하기",
                    "category": "history",
                    "score_value": {"nature": 1, "eat": 0, "history": 3, "activity": 0, "healing": 1},
                    "sort_order": 3,
                },
                {
                    "content": "오전부터 바로 카약이나 모터보트 타러 가기",
                    "category": "activity",
                    "score_value": {"nature": 0, "eat": 0, "history": 0, "activity": 3, "healing": 0},
                    "sort_order": 4,
                },
            ],
        },
        {
            "question": "나에게 있어 완벽한 하루의 마무리는?",
            "sort_order": 3,
            "options": [
                {
                    "content": "조용한 숙소에서 조용히 불멍이나 스파를 하며 피로 풀기",
                    "category": "healing",
                    "score_value": {"nature": 1, "eat": 0, "history": 0, "activity": 0, "healing": 3},
                    "sort_order": 1,
                },
                {
                    "content": "북적이는 야시장에서 맛있는 길거리 음식에 맥주 한잔하기",
                    "category": "food",
                    "score_value": {"nature": 0, "eat": 3, "history": 0, "activity": 1, "healing": 0},
                    "sort_order": 2,
                },
                {
                    "content": "문화재 야간 개장이나 예쁜 야경이 있는 성곽길 걷기",
                    "category": "history",
                    "score_value": {"nature": 2, "eat": 0, "history": 3, "activity": 0, "healing": 1},
                    "sort_order": 3,
                },
                {
                    "content": "야간 테마파크를 가거나 신나는 미디어 아트쇼 보러 가기",
                    "category": "activity",
                    "score_value": {"nature": 0, "eat": 0, "history": 1, "activity": 3, "healing": 0},
                    "sort_order": 4,
                },
            ],
        },
        {
            "question": "친구가 나를 부르는 별명 중 가장 마음에 드는 것은?",
            "sort_order": 4,
            "options": [
                {
                    "content": "자연을 찾아 유랑하는 평화주의 프로 힐러",
                    "category": "healing",
                    "score_value": {"nature": 2, "eat": 0, "history": 0, "activity": 0, "healing": 3},
                    "sort_order": 1,
                },
                {
                    "content": "맛집 지도를 머릿속에 다 꿰고 있는 미식 내비게이터",
                    "category": "food",
                    "score_value": {"nature": 0, "eat": 3, "history": 0, "activity": 0, "healing": 0},
                    "sort_order": 2,
                },
                {
                    "content": "관광지 안내판을 다 읽어보는 걸어 다니는 백과사전",
                    "category": "history",
                    "score_value": {"nature": 0, "eat": 0, "history": 3, "activity": 0, "healing": 0},
                    "sort_order": 3,
                },
                {
                    "content": "아침부터 밤까지 에너지가 뿜어져 나오는 지치지 않는 철인",
                    "category": "activity",
                    "score_value": {"nature": 0, "eat": 0, "history": 0, "activity": 3, "healing": 0},
                    "sort_order": 4,
                },
            ],
        },
    ]

    for q_data in questions_data:
        q_stmt = select(TripQuestion).where(
            TripQuestion.sort_order == q_data["sort_order"],
            TripQuestion.deleted_at.is_(None)
        )
        q_result = await session.execute(q_stmt)
        question = q_result.scalars().first()

        if question:
            question.question = q_data["question"]
        else:
            question = TripQuestion(
                question=q_data["question"],
                sort_order=q_data["sort_order"]
            )
            session.add(question)
            await session.flush()

        for opt_data in q_data["options"]:
            opt_stmt = select(TripQuestionOption).where(
                TripQuestionOption.question_id == question.id,
                TripQuestionOption.sort_order == opt_data["sort_order"],
                TripQuestionOption.deleted_at.is_(None)
            )
            opt_result = await session.execute(opt_stmt)
            option = opt_result.scalars().first()

            if option:
                option.content = opt_data["content"]
                option.category = opt_data["category"]
                option.score_value = opt_data["score_value"]
            else:
                option = TripQuestionOption(
                    question_id=question.id,
                    content=opt_data["content"],
                    category=opt_data["category"],
                    score_value=opt_data["score_value"],
                    sort_order=opt_data["sort_order"]
                )
                session.add(option)

    print("Success: Survey questions and options seeded (upserted).")


async def _main() -> None:
    reset = "--reset" in sys.argv
    async with AsyncSessionLocal() as session:
        await seed_survey(session, reset=reset)
        await session.commit()


if __name__ == "__main__":
    asyncio.run(_main())