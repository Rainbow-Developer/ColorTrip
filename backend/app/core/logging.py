"""공통 JSON 로깅과 요청 로깅 미들웨어.

규약: docs/conventions/logging-monitoring.md
스펙: docs/specs/020-backend-logging/
"""

from __future__ import annotations

import json
import logging
import re
import sys
import time
from collections.abc import Mapping
from contextvars import ContextVar
from datetime import UTC, date, datetime
from enum import Enum
from types import TracebackType
from typing import Any, TextIO
from uuid import uuid4

from fastapi import FastAPI
from starlette.datastructures import Headers, MutableHeaders
from starlette.types import ASGIApp, Message, Receive, Scope, Send

REQUEST_ID_HEADER = "X-Request-ID"
REQUEST_LOGGER_NAME = "app.request"
DEFAULT_REQUEST_ID = "-"

_request_id_context: ContextVar[str] = ContextVar("request_id", default=DEFAULT_REQUEST_ID)
_REQUEST_ID_RE = re.compile(r"^[A-Za-z0-9._:/@+-]{1,128}$")
_AUTHORIZATION_RE = re.compile(
    r"(?i)(\bauthorization\b[\"']?\s*[:=]\s*[\"']?)"
    r"(?:(?:bearer|basic)\s+)?[^\"'\s&,}]+"
)
_CREDENTIAL_RE = re.compile(r"(?i)\b(bearer|basic)(\s+)[A-Za-z0-9._~+/-]+=*")
_SENSITIVE_KEY_RE = re.compile(
    r"(?i)\b(access_token|refresh_token|id_token|authorization|jwt_secret_key|"
    r"client_secret|secret|password|serviceKey|service_key|api_key|token)\b"
    r"([\"']?\s*[:=]\s*)(\"[^\"]*\"|'[^']*'|[^\s&,}]+)"
)
_SENSITIVE_FIELD_NAMES = {
    "accesstoken",
    "apikey",
    "authorization",
    "clientsecret",
    "credential",
    "credentials",
    "idtoken",
    "jwtsecretkey",
    "password",
    "refreshtoken",
    "secret",
    "servicekey",
    "token",
}
_REDACTED = "[REDACTED]"

_LOG_RECORD_RESERVED_ATTRS = {
    "args",
    "asctime",
    "created",
    "exc_info",
    "exc_text",
    "filename",
    "funcName",
    "levelname",
    "levelno",
    "lineno",
    "module",
    "msecs",
    "message",
    "msg",
    "name",
    "pathname",
    "process",
    "processName",
    "relativeCreated",
    "stack_info",
    "thread",
    "threadName",
    "taskName",
}
_EXTRA_FIELDS = {"request_id", "method", "path", "status_code", "duration_ms", "client_ip"}
_VALID_LOG_LEVELS = {"DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"}
_NOISY_THIRD_PARTY_LOGGERS = ("httpx", "httpcore")


def current_request_id() -> str:
    """현재 요청의 request id를 반환한다."""
    return _request_id_context.get()


def resolve_log_level(app_env: str, log_level: str | None = None) -> str:
    """환경과 override 설정으로 최종 로그 레벨 이름을 결정한다."""
    if log_level is not None and log_level.strip():
        normalized = log_level.strip().upper()
        if normalized not in _VALID_LOG_LEVELS:
            raise ValueError("LOG_LEVEL must be one of DEBUG, INFO, WARNING, ERROR, CRITICAL.")
        return normalized

    env = app_env.strip().lower()
    return "DEBUG" if env in {"local", "test"} else "INFO"


def redact_sensitive_data(value: str) -> str:
    """대표적인 토큰·시크릿 문자열을 로그 출력 전에 마스킹한다."""
    redacted = _AUTHORIZATION_RE.sub(rf"\1{_REDACTED}", value)
    redacted = _CREDENTIAL_RE.sub(rf"\1\2{_REDACTED}", redacted)
    return _SENSITIVE_KEY_RE.sub(_redact_sensitive_match, redacted)


def _redact_sensitive_match(match: re.Match[str]) -> str:
    raw_value = match.group(3)
    quote = (
        raw_value[0]
        if len(raw_value) >= 2 and raw_value[0] in {'"', "'"} and raw_value[0] == raw_value[-1]
        else ""
    )
    redacted_value = f"{quote}{_REDACTED}{quote}"
    return f"{match.group(1)}{match.group(2)}{redacted_value}"


def _safe_request_id(value: str | None) -> str:
    candidate = (value or "").strip()
    if not candidate or not _REQUEST_ID_RE.fullmatch(candidate):
        return uuid4().hex
    return candidate


class RequestContextFilter(logging.Filter):
    """LogRecord에 현재 요청 request_id를 추가하고 메시지를 redaction한다."""

    def filter(self, record: logging.LogRecord) -> bool:
        if not hasattr(record, "request_id"):
            record.request_id = current_request_id()
        record.msg = redact_sensitive_data(record.getMessage())
        record.args = ()
        return True


class JsonLogFormatter(logging.Formatter):
    """Cloud Logging에서 읽기 쉬운 JSON 한 줄 로그 formatter."""

    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "time": datetime.fromtimestamp(record.created, tz=UTC).isoformat(
                timespec="milliseconds"
            ),
            "severity": record.levelname,
            "message": redact_sensitive_data(record.getMessage()),
            "logger": record.name,
        }

        for field in _EXTRA_FIELDS:
            value = getattr(record, field, None)
            if value is not None and value != DEFAULT_REQUEST_ID:
                payload[field] = _json_safe(value)

        payload["logging.googleapis.com/sourceLocation"] = {
            "file": record.pathname,
            "line": record.lineno,
            "function": record.funcName,
        }

        if record.exc_info:
            payload["exception"] = redact_sensitive_data(self.formatException(record.exc_info))
        if record.stack_info:
            payload["stack"] = redact_sensitive_data(self.formatStack(record.stack_info))

        for key, value in record.__dict__.items():
            if key in _LOG_RECORD_RESERVED_ATTRS or key in payload or key in _EXTRA_FIELDS:
                continue
            if key.startswith("_") or key.startswith("logging."):
                continue
            payload[key] = _REDACTED if _is_sensitive_key(key) else _json_safe(value)

        return json.dumps(payload, ensure_ascii=False, separators=(",", ":"))


class SensitiveDataFilter(logging.Filter):
    """핸들러에 적용하는 민감정보 마스킹 필터."""

    def filter(self, record: logging.LogRecord) -> bool:
        record.msg = redact_sensitive_data(record.getMessage())
        record.args = ()
        return True


def setup_logging(
    *, app_env: str, log_level: str | None = None, stream: TextIO | None = None
) -> None:
    """앱 공통 로깅 설정을 적용한다."""
    resolved_level = resolve_log_level(app_env, log_level)
    handler = logging.StreamHandler(stream or sys.stdout)
    handler.setLevel(resolved_level)
    handler.setFormatter(JsonLogFormatter())
    handler.addFilter(RequestContextFilter())
    handler.addFilter(SensitiveDataFilter())

    root_logger = logging.getLogger()
    root_logger.disabled = False
    root_logger.handlers = [handler]
    root_logger.setLevel(resolved_level)

    for logger_name in ("app", "uvicorn", "uvicorn.error"):
        logger = logging.getLogger(logger_name)
        logger.disabled = False
        logger.handlers = []
        logger.propagate = True
        logger.setLevel(resolved_level)

    _enable_existing_app_loggers()
    _configure_third_party_loggers()

    access_logger = logging.getLogger("uvicorn.access")
    access_logger.handlers = []
    access_logger.propagate = False
    access_logger.disabled = True


class RequestLoggingMiddleware:
    """응답 전송 완료까지 측정하는 순수 ASGI 요청 로깅 미들웨어."""

    def __init__(self, app: ASGIApp) -> None:
        self.app = app
        self.request_logger = logging.getLogger(REQUEST_LOGGER_NAME)

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        request_id = _safe_request_id(Headers(scope=scope).get(REQUEST_ID_HEADER))
        scope.setdefault("state", {})["request_id"] = request_id
        token = _request_id_context.set(request_id)
        started_at = time.perf_counter()
        status_code = 500

        async def send_with_request_id(message: Message) -> None:
            nonlocal status_code
            if message["type"] == "http.response.start":
                status_code = int(message["status"])
                MutableHeaders(scope=message)[REQUEST_ID_HEADER] = request_id
            await send(message)

        try:
            await self.app(scope, receive, send_with_request_id)
        except Exception:
            duration_ms = _duration_ms(started_at)
            self.request_logger.exception(
                "request failed",
                extra=_request_extra(scope, request_id, status_code, duration_ms),
            )
            raise
        else:
            duration_ms = _duration_ms(started_at)
            log_method = (
                self.request_logger.error if status_code >= 500 else self.request_logger.info
            )
            message = "request failed" if status_code >= 500 else "request completed"
            log_method(
                message,
                extra=_request_extra(scope, request_id, status_code, duration_ms),
            )
        finally:
            _request_id_context.reset(token)


def register_request_logging(app: FastAPI) -> None:
    """FastAPI 앱에 요청 로깅 미들웨어를 등록한다."""
    app.add_middleware(RequestLoggingMiddleware)


def request_id_from_scope(scope: Mapping[str, Any]) -> str | None:
    """ASGI scope에 저장된 검증 완료 request id를 반환한다."""
    state = scope.get("state")
    if not isinstance(state, Mapping):
        return None

    request_id = state.get("request_id")
    if not isinstance(request_id, str) or not _REQUEST_ID_RE.fullmatch(request_id):
        return None
    return request_id


def _duration_ms(started_at: float) -> float:
    return round((time.perf_counter() - started_at) * 1000, 3)


def _enable_existing_app_loggers() -> None:
    for logger_name, logger in logging.Logger.manager.loggerDict.items():
        if not isinstance(logger, logging.Logger):
            continue
        if not logger_name.startswith("app."):
            continue

        logger.disabled = False
        logger.handlers = []
        logger.propagate = True
        logger.setLevel(logging.NOTSET)


def _configure_third_party_loggers() -> None:
    for logger_name in _NOISY_THIRD_PARTY_LOGGERS:
        logger = logging.getLogger(logger_name)
        logger.disabled = False
        logger.handlers = []
        logger.propagate = True
        logger.setLevel(logging.WARNING)


def _json_safe(value: Any) -> Any:
    if isinstance(value, str):
        return redact_sensitive_data(value)
    if value is None or isinstance(value, (bool, int, float)):
        return value
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    if isinstance(value, Enum):
        return _json_safe(value.value)
    if isinstance(value, Mapping):
        return {
            redact_sensitive_data(str(key)): (
                _REDACTED if _is_sensitive_key(key) else _json_safe(item)
            )
            for key, item in value.items()
        }
    if isinstance(value, (list, tuple)):
        return [_json_safe(item) for item in value]
    if isinstance(value, set):
        return [_json_safe(item) for item in sorted(value, key=repr)]
    return redact_sensitive_data(str(value))


def _is_sensitive_key(key: Any) -> bool:
    normalized = re.sub(r"[^a-z0-9]", "", str(key).lower())
    if normalized in _SENSITIVE_FIELD_NAMES:
        return True
    return normalized.endswith(
        ("apikey", "authorization", "password", "secret", "secretkey", "servicekey", "token")
    ) or normalized.startswith(("password", "secret"))


def _request_extra(
    scope: Scope,
    request_id: str,
    status_code: int,
    duration_ms: float,
) -> dict[str, str | int | float | None]:
    client = scope.get("client")
    return {
        "request_id": request_id,
        "method": str(scope.get("method", "")),
        "path": str(scope.get("path", "")),
        "status_code": status_code,
        "duration_ms": duration_ms,
        "client_ip": client[0] if client else None,
    }


def format_exception(exc_info: tuple[type[BaseException], BaseException, TracebackType]) -> str:
    """테스트와 확장 지점에서 사용할 수 있는 예외 문자열 포맷 헬퍼."""
    return redact_sensitive_data(logging.Formatter().formatException(exc_info))
