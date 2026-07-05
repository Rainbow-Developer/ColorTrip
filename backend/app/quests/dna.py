"""여행 DNA 연동 seam.

DNA(설문) 도메인이 아직 없어 추천은 이 함수를 통해서만 DNA를 조회한다
(docs/specs/010-journey/plan.md 의사결정 4). DNA 도메인이 구현되면 이 함수 본문만
travel DNA 조회로 교체하고, 그 전까지 추천은 `?category=` 파라미터로 동작한다.
"""

from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.enums import Category


async def get_user_primary_category(session: AsyncSession, user_id: UUID) -> Category | None:
    """사용자의 대표 여행 DNA 카테고리를 반환한다. 미산출이면 None."""
    # TODO(DNA 도메인): 설문 결과(travel DNA) 조회로 교체
    return None
