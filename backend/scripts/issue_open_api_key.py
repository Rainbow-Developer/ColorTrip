"""지자체 등에 오픈 API 서비스키를 발급하는 CLI — docs/specs/070-municipal-open-api/

원문 키는 이 실행 시점에만 출력되고 DB에는 해시만 저장되므로, 분실 시 재발급(신규 키 발급 +
기존 키 회수)해야 한다.

실행:
    cd backend && uv run python scripts/issue_open_api_key.py --name "단양군청"
    cd backend && uv run python scripts/issue_open_api_key.py --revoke <key-id>
"""

import argparse
import asyncio
import sys
from pathlib import Path
from uuid import UUID

BACKEND = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND))

from app.core.database import AsyncSessionLocal  # noqa: E402
from app.core.security import generate_open_api_key, hash_open_api_key  # noqa: E402
from app.open_api.models import OpenApiKey  # noqa: E402


async def issue(name: str) -> None:
    key = generate_open_api_key()
    async with AsyncSessionLocal() as session:
        record = OpenApiKey(name=name, key_hash=hash_open_api_key(key))
        session.add(record)
        await session.commit()
        print(f"Issued open API key for {name!r} (ID: {record.id})")

    print("\n======================= COPY SERVICE KEY =======================")
    print(key)
    print("==================================================================")
    print("이 키는 지금만 출력됩니다 — DB에는 해시만 저장되어 다시 조회할 수 없습니다.\n")


async def revoke(key_id: str) -> None:
    async with AsyncSessionLocal() as session:
        record = await session.get(OpenApiKey, UUID(key_id))
        if record is None:
            print(f"No open API key found with ID {key_id}")
            return
        record.is_active = False
        await session.commit()
        print(f"Revoked open API key {record.name!r} (ID: {record.id})")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--name", help="키를 발급할 대상 이름 (예: '단양군청')")
    group.add_argument("--revoke", metavar="KEY_ID", help="비활성화할 키의 ID")
    args = parser.parse_args()

    if args.name:
        asyncio.run(issue(args.name))
    else:
        asyncio.run(revoke(args.revoke))


if __name__ == "__main__":
    main()
