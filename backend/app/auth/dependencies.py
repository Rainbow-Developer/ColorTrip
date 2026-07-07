"""Auth dependencies for protected APIs."""

from typing import Annotated

from fastapi import Depends, Header
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.models import User
from app.auth.service import get_active_user
from app.core.database import get_session
from app.core.exceptions import AppException, ErrorCode
from app.core.security import decode_access_token

type AuthorizationHeader = Annotated[str | None, Header()]


async def get_current_user(
    authorization: AuthorizationHeader = None,
    session: AsyncSession = Depends(get_session),
) -> User:
    token = _extract_bearer_token(authorization)
    user_id = decode_access_token(token)
    user = await get_active_user(session, user_id)
    if user is None:
        raise AppException(ErrorCode.UNAUTHORIZED_ERROR, "Authenticated user is not active.")
    return user


type CurrentUser = Annotated[User, Depends(get_current_user)]


def _extract_bearer_token(authorization: str | None) -> str:
    if authorization is None:
        raise AppException(ErrorCode.UNAUTHORIZED_ERROR, "Authorization header is required.")

    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise AppException(
            ErrorCode.UNAUTHORIZED_ERROR,
            "Authorization header must use Bearer token.",
        )
    return token
