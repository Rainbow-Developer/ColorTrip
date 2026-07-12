"""Alembic 마이그레이션 환경 (async).

DB URL과 메타데이터는 앱 설정·모델에서 가져온다(단일 출처).
"""

import asyncio
from logging.config import fileConfig

from sqlalchemy import pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import async_engine_from_config

from alembic import context

# 모델을 import해야 Base.metadata에 테이블이 등록된다.
from app.auth.models import RefreshToken, User  # noqa: F401
from app.core.base import Base
from app.core.config import settings
from app.journeys.models import Journey, JourneyQuest  # noqa: F401
from app.progress.models import MapProgress  # noqa: F401
from app.quests.models import Quest, QuestProgress  # noqa: F401
from app.regions.models import Region  # noqa: F401
from app.timeline.models import TimelineEvent  # noqa: F401
from app.trip_dna.models import (  # noqa: F401
    TripQuestion,
    TripQuestionOption,
    TripReply,
    UserDnaHistory,
)

config = context.config
config.set_main_option("sqlalchemy.url", settings.database_url)

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    context.configure(
        url=settings.database_url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection: Connection) -> None:
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations() -> None:
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await connectable.dispose()


def run_migrations_online() -> None:
    existing_connection = config.attributes.get("connection")
    if existing_connection is not None:
        do_run_migrations(existing_connection)
        return

    asyncio.run(run_async_migrations())


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
