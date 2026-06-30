"""비동기 DB 엔진·세션.

규약: docs/conventions/backend.md (SQLAlchemy 2.0, async/await 전면)
"""

from collections.abc import AsyncGenerator
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.core.config import settings

engine_kwargs: dict[str, Any] = {"pool_pre_ping": True}
if settings.app_env.strip().lower() == "test":
    engine_kwargs["poolclass"] = NullPool

engine = create_async_engine(settings.database_url, **engine_kwargs)
AsyncSessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


async def get_session() -> AsyncGenerator[AsyncSession]:
    """FastAPI 의존성: 요청 단위 DB 세션."""
    async with AsyncSessionLocal() as session:
        yield session
