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


def generate_open_api_key() -> str:
    """지자체 등에 발급하는 오픈 API 서비스키 원문을 생성한다."""
    return secrets.token_urlsafe(32)


def _open_api_key_secret() -> bytes:
    """서비스키 해시 키 — OPEN_API_KEY_SECRET 미설정 시 JWT_SECRET_KEY에서 파생한다
    (QR 서명 키와 동일한 패턴, app/verifications/service.py의 _qr_secret 참고)."""
    secret = settings.open_api_key_secret.strip()
    if secret:
        return secret.encode("utf-8")
    return hashlib.sha256(f"{settings.jwt_secret_key}:open_api_key".encode()).digest()


def hash_open_api_key(key: str) -> str:
    """서비스키 원문을 해시로 변환 — DB에는 이 값만 저장한다(refresh token과 동일한 방식).

    JWT_SECRET_KEY를 직접 쓰지 않고 도메인을 분리한 파생 키를 쓴다 — 사용자 세션 관련
    사고로 JWT_SECRET_KEY를 회전시켜도 이미 발급한 지자체 키가 함께 무효화되지 않는다.
    """
    digest = hmac.new(
        _open_api_key_secret(),
        key.encode(),
        hashlib.sha256,
    )
    return digest.hexdigest()
