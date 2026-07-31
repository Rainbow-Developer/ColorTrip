"""여행 DNA 연동 seam.

추천은 이 함수를 통해서만 DNA를 조회한다(docs/specs/010-journey/plan.md 의사결정 4).
설문(trip_dna) 제출 시 갱신되는 User.dna를 읽는다 — 값 체계는 Category와 동일
(docs/specs/040-home-region-recommendation/plan.md).
"""

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.models import User
from app.core.enums import Category


async def get_user_primary_category(session: AsyncSession, user_id: UUID) -> Category | None:
    """사용자의 대표 여행 DNA 카테고리를 반환한다. 미산출이면 None."""
    dna = await session.scalar(select(User.dna).where(User.id == user_id))
    return Category(dna) if dna else None
