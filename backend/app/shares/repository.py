from __future__ import annotations

import secrets
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.shares.models import Share


class ShareRepository:
    async def _generate_unique_share_code(self, session: AsyncSession) -> str:
        """8자리의 중복되지 않는 URL-safe 고유 숏코드를 생성합니다."""
        for _ in range(10):  # 최대 10회 재시도
            code = secrets.token_urlsafe(6)[:8].replace("-", "a").replace("_", "b")
            stmt = select(Share).where(Share.share_code == code)
            result = await session.execute(stmt)
            if result.scalars().first() is None:
                return code
        # 예외 상황 대비 UUID 변환 코드
        return uuid.uuid4().hex[:8]

    async def create(
        self, session: AsyncSession, user_id: uuid.UUID, share_style: str
    ) -> Share:
        """새 공유 숏코드 및 카드를 생성하고 영속화합니다."""
        share_code = await self._generate_unique_share_code(session)
        db_obj = Share(
            user_id=user_id,
            share_code=share_code,
            share_style=share_style,
        )
        session.add(db_obj)
        await session.flush()
        return db_obj

    async def get_by_code(
        self, session: AsyncSession, share_code: str
    ) -> Share | None:
        """share_code 기반으로 공유 정보 및 생성 사용자 정보를 함께 로드합니다."""
        stmt = (
            select(Share)
            .options(joinedload(Share.user))
            .where(Share.share_code == share_code, Share.deleted_at.is_(None))
        )
        result = await session.execute(stmt)
        return result.scalars().first()
