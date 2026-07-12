import asyncio
from datetime import timedelta

import jwt
from sqlalchemy import select

from app.auth.models import User
from app.core.base import now_kst
from app.core.config import settings
from app.core.database import AsyncSessionLocal


def create_long_lived_access_token(user_id) -> str:
    """로컬 테스트용 7일 만료 토큰을 생성합니다."""
    now = now_kst()
    payload = {
        "sub": str(user_id),
        "type": "access",
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(days=7)).timestamp()),  # 7일 만료
    }
    return jwt.encode(payload, settings.jwt_secret_key, algorithm="HS256")


async def main():
    async with AsyncSessionLocal() as session:
        # 1. 기존 유저가 있는지 확인
        result = await session.execute(select(User).limit(1))
        user = result.scalars().first()

        if not user:
            # 2. 유저가 전혀 없으면 로컬용 모크 유저 생성
            user = User(
                social_provider="kakao",
                social_id="mock_social_id_local_test",
                nickname="테스트유저",
                email="test_user@colortrip.com",
            )
            session.add(user)
            await session.commit()
            print(f"Created local test user: {user.nickname} (ID: {user.id})")
        else:
            print(f"Using existing user: {user.nickname} (ID: {user.id})")

        # 3. 7일 유효 토큰 발행
        token = create_long_lived_access_token(user.id)

        print("\n======================= COPY DEV JWT TOKEN =======================")
        print(token)
        print("==================================================================\n")


if __name__ == "__main__":
    asyncio.run(main())
