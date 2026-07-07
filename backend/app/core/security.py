"""JWT and token primitives."""

import hashlib
import hmac
import secrets
from datetime import timedelta
from typing import Any, cast
from uuid import UUID

import jwt

from app.core.base import now_kst
from app.core.config import settings
from app.core.exceptions import AppException, ErrorCode


def create_access_token(*, user_id: UUID) -> str:
    now = now_kst()
    payload: dict[str, object] = {
        "sub": str(user_id),
        "type": "access",
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=settings.access_token_ttl_minutes)).timestamp()),
    }
    return cast(str, jwt.encode(payload, settings.jwt_secret_key, algorithm="HS256"))


def decode_access_token(token: str) -> UUID:
    try:
        payload_raw: Any = jwt.decode(
            token,
            settings.jwt_secret_key,
            algorithms=["HS256"],
            options={"require": ["exp", "iat", "sub", "type"]},
        )
    except jwt.ExpiredSignatureError as exc:
        raise AppException(ErrorCode.TOKEN_EXPIRED_ERROR, "Access token has expired.") from exc
    except jwt.PyJWTError as exc:
        raise AppException(ErrorCode.UNAUTHORIZED_ERROR, "Access token is invalid.") from exc

    payload = cast(dict[str, object], payload_raw)
    token_type = payload.get("type")
    subject = payload.get("sub")
    if token_type != "access" or not isinstance(subject, str):
        raise AppException(ErrorCode.UNAUTHORIZED_ERROR, "Access token is invalid.")

    try:
        return UUID(subject)
    except ValueError as exc:
        raise AppException(ErrorCode.UNAUTHORIZED_ERROR, "Access token is invalid.") from exc


def create_refresh_token() -> str:
    return secrets.token_urlsafe(48)


def hash_refresh_token(token: str) -> str:
    digest = hmac.new(
        settings.jwt_secret_key.encode(),
        token.encode(),
        hashlib.sha256,
    )
    return digest.hexdigest()
