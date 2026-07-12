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

from fastapi import FastAPI, Request
from fastapi.responses import PlainTextResponse

REQUEST_ID_HEADER = "X-Request-ID"
REQUEST_LOGGER_NAME = "app.request"
DEFAULT_REQUEST_ID = "-"

_request_id_context: ContextVar[str] = ContextVar("request_id", default=DEFAULT_REQUEST_ID)
_REQUEST_ID_RE = re.compile(r"^[A-Za-z0-9._:/@+-]{1,128}$")
_BEARER_RE = re.compile(r"(?i)(Bearer\s+)[A-Za-z0-9._~+/-]+=*")
_SENSITIVE_KEY_RE = re.compile(
    r"(?i)\b(access_token|refresh_token|id_token|authorization|jwt_secret_key|"
    r"secret|password|serviceKey|service_key|api_key|token)\b"
    r"([\"']?\s*[:=]\s*[\"']?)([^\"'\s&,}]+)"
)

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
    redacted = _BEARER_RE.sub(r"\1[REDACTED]", value)
    return _SENSITIVE_KEY_RE.sub(r"\1\2[REDACTED]", redacted)


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
            payload["exception"] = self.formatException(record.exc_info)
        if record.stack_info:
            payload["stack"] = self.formatStack(record.stack_info)

        for key, value in record.__dict__.items():
            if key in _LOG_RECORD_RESERVED_ATTRS or key in payload or key in _EXTRA_FIELDS:
                continue
            if key.startswith("_") or key.startswith("logging."):
                continue
            payload[key] = _json_safe(value)

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


def register_request_logging(app: FastAPI) -> None:
    """FastAPI 앱에 요청 로깅 미들웨어를 등록한다."""
    request_logger = logging.getLogger(REQUEST_LOGGER_NAME)

    @app.middleware("http")
    async def _log_request(request: Request, call_next: Any) -> Any:
        request_id = _safe_request_id(request.headers.get(REQUEST_ID_HEADER))
        token = _request_id_context.set(request_id)
        started_at = time.perf_counter()
        status_code = 500

        try:
            response = await call_next(request)
            status_code = response.status_code
        except Exception:
            duration_ms = _duration_ms(started_at)
            request_logger.exception(
                "request failed",
                extra=_request_extra(request, request_id, status_code, duration_ms),
            )
            return PlainTextResponse(
                "Internal Server Error",
                status_code=status_code,
                headers={REQUEST_ID_HEADER: request_id},
            )
        else:
            duration_ms = _duration_ms(started_at)
            response.headers[REQUEST_ID_HEADER] = request_id
            request_logger.info(
                "request completed",
                extra=_request_extra(request, request_id, status_code, duration_ms),
            )
            return response
        finally:
            _request_id_context.reset(token)


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
        return {str(_json_safe(key)): _json_safe(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_json_safe(item) for item in value]
    if isinstance(value, set):
        return [_json_safe(item) for item in sorted(value, key=repr)]
    return redact_sensitive_data(str(value))


def _request_extra(
    request: Request,
    request_id: str,
    status_code: int,
    duration_ms: float,
) -> dict[str, str | int | float | None]:
    return {
        "request_id": request_id,
        "method": request.method,
        "path": request.url.path,
        "status_code": status_code,
        "duration_ms": duration_ms,
        "client_ip": request.client.host if request.client else None,
    }


def format_exception(exc_info: tuple[type[BaseException], BaseException, TracebackType]) -> str:
    """테스트와 확장 지점에서 사용할 수 있는 예외 문자열 포맷 헬퍼."""
    return logging.Formatter().formatException(exc_info)
