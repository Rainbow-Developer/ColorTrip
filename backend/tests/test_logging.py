from __future__ import annotations

import asyncio
import json
import logging
import sys
from collections.abc import Sequence
from datetime import UTC, datetime
from io import StringIO
from typing import Any, cast
from uuid import uuid4

import pytest
from fastapi import FastAPI
from fastapi.responses import StreamingResponse
from httpx import ASGITransport, AsyncClient

from app.core.config import Settings
from app.core.exceptions import AppException, ErrorCode, register_exception_handlers
from app.core.logging import (
    REQUEST_ID_HEADER,
    JsonLogFormatter,
    redact_sensitive_data,
    register_request_logging,
    resolve_log_level,
    setup_logging,
)


@pytest.fixture(autouse=True)
def restore_logging_state():
    """각 테스트가 전역 logging 설정을 다음 테스트로 유출하지 않게 한다."""
    manager = logging.Logger.manager
    original_logger_dict = manager.loggerDict.copy()
    original_logger_states = {
        name: _snapshot_logger(logger)
        for name, logger in original_logger_dict.items()
        if isinstance(logger, logging.Logger)
    }
    original_root_state = _snapshot_logger(logging.getLogger())
    original_disable = manager.disable
    original_handler_ids = {
        id(handler)
        for logger in [logging.getLogger(), *original_logger_dict.values()]
        if isinstance(logger, logging.Logger)
        for handler in logger.handlers
    }

    try:
        yield
    finally:
        seen_handler_ids: set[int] = set()
        current_loggers = [logging.getLogger(), *manager.loggerDict.values()]
        for logger in current_loggers:
            if not isinstance(logger, logging.Logger):
                continue
            for handler in logger.handlers:
                handler_id = id(handler)
                if handler_id in original_handler_ids or handler_id in seen_handler_ids:
                    continue
                seen_handler_ids.add(handler_id)
                handler.close()

        manager.loggerDict.clear()
        manager.loggerDict.update(original_logger_dict)
        _restore_logger(logging.getLogger(), original_root_state)
        for name, state in original_logger_states.items():
            logger = original_logger_dict[name]
            assert isinstance(logger, logging.Logger)
            _restore_logger(logger, state)
        manager.disable = original_disable


def test_resolve_log_level_uses_env_defaults() -> None:
    assert resolve_log_level("local") == "DEBUG"
    assert resolve_log_level("test") == "DEBUG"
    assert resolve_log_level("dev") == "INFO"
    assert resolve_log_level("prod") == "INFO"


def test_resolve_log_level_allows_override() -> None:
    assert resolve_log_level("prod", "debug") == "DEBUG"
    assert resolve_log_level("local", "ERROR") == "ERROR"


def test_settings_rejects_invalid_log_level() -> None:
    with pytest.raises(ValueError, match="LOG_LEVEL"):
        _settings(log_level="verbose")


def test_settings_treats_blank_log_level_as_default() -> None:
    settings = _settings(log_level="")

    assert settings.log_level is None
    assert resolve_log_level(settings.app_env, settings.log_level) == "DEBUG"


def test_json_formatter_outputs_expected_fields() -> None:
    stream = StringIO()
    setup_logging(app_env="test", log_level="INFO", stream=stream)

    logger = logging.getLogger("app.test")
    logger.info(
        "request completed",
        extra={
            "request_id": "req-123",
            "method": "GET",
            "path": "/health",
            "status_code": 200,
            "duration_ms": 1.23,
            "client_ip": "127.0.0.1",
        },
    )

    payload = _single_payload(stream)
    assert payload["severity"] == "INFO"
    assert payload["message"] == "request completed"
    assert payload["logger"] == "app.test"
    assert payload["request_id"] == "req-123"
    assert payload["method"] == "GET"
    assert payload["path"] == "/health"
    assert payload["status_code"] == 200
    assert payload["duration_ms"] == 1.23
    assert payload["client_ip"] == "127.0.0.1"
    assert "time" in payload


def test_json_formatter_serializes_non_json_extra_values() -> None:
    stream = StringIO()
    setup_logging(app_env="test", log_level="INFO", stream=stream)
    user_id = uuid4()
    logged_at = datetime(2026, 7, 12, 12, 34, 56, tzinfo=UTC)

    logger = logging.getLogger("app.test")
    logger.info("user loaded", extra={"user_id": user_id, "logged_at": logged_at})

    payload = _single_payload(stream)
    assert payload["user_id"] == str(user_id)
    assert payload["logged_at"] == logged_at.isoformat()


def test_sensitive_data_is_redacted() -> None:
    message = (
        "Authorization: Bearer access-token-123 Authorization: Basic dXNlcjpwYXNz "
        "access_token=kakao-token serviceKey=tour-key password=secret "
        'client_secret="two word secret"'
    )

    redacted = redact_sensitive_data(message)

    assert "access-token-123" not in redacted
    assert "dXNlcjpwYXNz" not in redacted
    assert "kakao-token" not in redacted
    assert "tour-key" not in redacted
    assert "password=secret" not in redacted
    assert "two" not in redacted
    assert "word secret" not in redacted
    assert 'client_secret="[REDACTED]"' in redacted
    assert "[REDACTED]" in redacted


def test_json_formatter_redacts_sensitive_structured_extras() -> None:
    stream = StringIO()
    setup_logging(app_env="test", log_level="INFO", stream=stream)

    logger = logging.getLogger("app.test")
    logger.info(
        "authentication metadata",
        extra={
            "api_key": "top-level-secret",
            "profile": {
                "password": "nested-secret",
                "safe_value": "visible",
                "tokens": [{"access_token": "list-secret"}],
            },
        },
    )

    raw_log = stream.getvalue()
    payload = _single_payload(stream)
    assert "top-level-secret" not in raw_log
    assert "nested-secret" not in raw_log
    assert "list-secret" not in raw_log
    assert payload["api_key"] == "[REDACTED]"
    assert payload["profile"] == {
        "password": "[REDACTED]",
        "safe_value": "visible",
        "tokens": [{"access_token": "[REDACTED]"}],
    }


def test_json_formatter_redacts_exception_and_stack() -> None:
    try:
        raise RuntimeError("password=traceback-secret")
    except RuntimeError:
        record = logging.LogRecord(
            "app.test",
            logging.ERROR,
            __file__,
            1,
            "request failed",
            (),
            sys.exc_info(),
        )

    record.stack_info = "Authorization: Basic stack-secret"
    raw_log = JsonLogFormatter().format(record)
    payload = json.loads(raw_log)

    assert "traceback-secret" not in raw_log
    assert "stack-secret" not in raw_log
    assert "[REDACTED]" in payload["exception"]
    assert "[REDACTED]" in payload["stack"]


def test_setup_logging_reenables_existing_app_loggers() -> None:
    logger = logging.getLogger("app.request")
    logger.disabled = True
    stream = StringIO()

    setup_logging(app_env="test", log_level="INFO", stream=stream)
    logger.info("request completed", extra={"request_id": "req-reenabled"})

    payload = _single_payload(stream)
    assert payload["message"] == "request completed"
    assert payload["request_id"] == "req-reenabled"


def test_setup_logging_enforces_level_for_explicit_child_logger() -> None:
    stream = StringIO()
    setup_logging(app_env="test", log_level="ERROR", stream=stream)
    logger = logging.getLogger("third_party.explicit")
    logger.setLevel(logging.DEBUG)

    try:
        logger.warning("warning must be filtered")
        logger.error("error remains")
    finally:
        logger.setLevel(logging.NOTSET)

    payloads = _payloads(stream)
    assert [payload["message"] for payload in payloads] == ["error remains"]


@pytest.mark.asyncio
async def test_request_logging_adds_request_id_and_logs_metadata_only() -> None:
    stream = StringIO()
    setup_logging(app_env="test", log_level="INFO", stream=stream)
    app = FastAPI()
    register_request_logging(app)

    @app.post("/health")
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        response = await client.post(
            "/health?access_token=query-secret",
            json={"password": "body-secret"},
            headers={
                REQUEST_ID_HEADER: "req-abc-123",
                "Authorization": "Bearer header-secret",
            },
        )

    assert response.status_code == 200
    assert response.headers[REQUEST_ID_HEADER] == "req-abc-123"

    raw_logs = stream.getvalue()
    payload = _payloads(stream)[0]
    assert payload["message"] == "request completed"
    assert payload["request_id"] == "req-abc-123"
    assert payload["method"] == "POST"
    assert payload["path"] == "/health"
    assert payload["status_code"] == 200
    assert "duration_ms" in payload
    assert "query-secret" not in raw_logs
    assert "body-secret" not in raw_logs
    assert "header-secret" not in raw_logs
    assert "access_token" not in raw_logs
    assert "HTTP Request:" not in raw_logs


@pytest.mark.asyncio
async def test_request_logging_suppresses_third_party_query_logs() -> None:
    stream = StringIO()
    setup_logging(app_env="test", log_level="INFO", stream=stream)
    app = FastAPI()
    register_request_logging(app)

    @app.get("/health")
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        response = await client.get("/health?access_token=query-secret&foo=bar")

    assert response.status_code == 200
    raw_logs = stream.getvalue()
    assert "HTTP Request:" not in raw_logs
    assert "access_token" not in raw_logs
    assert "foo=bar" not in raw_logs
    assert "query-secret" not in raw_logs


@pytest.mark.asyncio
async def test_request_logging_generates_invalid_request_id() -> None:
    stream = StringIO()
    setup_logging(app_env="test", log_level="INFO", stream=stream)
    app = FastAPI()
    register_request_logging(app)

    @app.get("/health")
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        response = await client.get("/health", headers={REQUEST_ID_HEADER: "bad value"})

    generated_request_id = response.headers[REQUEST_ID_HEADER]
    assert generated_request_id != "bad value"
    assert len(generated_request_id) == 32

    payload = _payloads(stream)[0]
    assert payload["request_id"] == generated_request_id


@pytest.mark.asyncio
async def test_handler_logs_include_current_request_id() -> None:
    stream = StringIO()
    setup_logging(app_env="test", log_level="INFO", stream=stream)
    app = FastAPI()
    register_request_logging(app)
    logger = logging.getLogger("app.handler")

    @app.get("/inside")
    async def inside() -> dict[str, str]:
        logger.info("inside handler")
        return {"status": "ok"}

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        response = await client.get("/inside", headers={REQUEST_ID_HEADER: "req-inside"})

    assert response.status_code == 200

    payloads = _payloads(stream)
    handler_payload = next(
        payload for payload in payloads if payload["message"] == "inside handler"
    )
    assert handler_payload["request_id"] == "req-inside"


@pytest.mark.asyncio
async def test_unhandled_exception_is_logged_as_error() -> None:
    stream = StringIO()
    setup_logging(app_env="test", log_level="INFO", stream=stream)
    app = FastAPI()
    register_request_logging(app)
    register_exception_handlers(app)

    @app.get("/boom")
    async def boom() -> dict[str, str]:
        raise RuntimeError("boom")

    transport = ASGITransport(app=app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        response = await client.get("/boom", headers={REQUEST_ID_HEADER: "req-boom"})

    assert response.status_code == 500
    assert response.headers[REQUEST_ID_HEADER] == "req-boom"
    assert response.json() == {
        "code": "INTERNAL_ERROR",
        "status": 500,
        "message": "서버 오류가 발생했습니다.",
        "data": None,
    }

    payload = _payloads(stream)[0]
    assert payload["severity"] == "ERROR"
    assert payload["message"] == "request failed"
    assert payload["request_id"] == "req-boom"
    assert payload["path"] == "/boom"
    assert payload["status_code"] == 500
    assert "exception" in payload


@pytest.mark.asyncio
async def test_request_duration_includes_streaming_response_completion() -> None:
    stream = StringIO()
    setup_logging(app_env="test", log_level="INFO", stream=stream)
    app = FastAPI()
    register_request_logging(app)

    async def chunks():
        yield b"first"
        await asyncio.sleep(0.03)
        yield b"second"

    @app.get("/stream")
    async def stream_response() -> StreamingResponse:
        return StreamingResponse(chunks())

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        response = await client.get("/stream")

    assert response.status_code == 200
    payload = _single_payload(stream)
    assert payload["duration_ms"] >= 20


@pytest.mark.asyncio
async def test_streaming_exception_is_logged_as_error() -> None:
    stream = StringIO()
    setup_logging(app_env="test", log_level="INFO", stream=stream)
    app = FastAPI()
    register_request_logging(app)

    async def broken_chunks():
        yield b"partial"
        raise RuntimeError("stream failed")

    @app.get("/broken-stream")
    async def broken_stream() -> StreamingResponse:
        return StreamingResponse(broken_chunks())

    transport = ASGITransport(app=app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        response = await client.get("/broken-stream", headers={REQUEST_ID_HEADER: "req-stream"})

    assert response.status_code == 200
    assert response.headers[REQUEST_ID_HEADER] == "req-stream"
    payload = _single_payload(stream)
    assert payload["severity"] == "ERROR"
    assert payload["message"] == "request failed"
    assert payload["request_id"] == "req-stream"
    assert payload["status_code"] == 200


@pytest.mark.asyncio
async def test_handled_server_error_is_logged_as_error() -> None:
    stream = StringIO()
    setup_logging(app_env="test", log_level="INFO", stream=stream)
    app = FastAPI()
    register_request_logging(app)
    register_exception_handlers(app)

    @app.get("/handled-error")
    async def handled_error() -> None:
        raise AppException(ErrorCode.INTERNAL_ERROR)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        response = await client.get("/handled-error")

    assert response.status_code == 500
    payload = _single_payload(stream)
    assert payload["severity"] == "ERROR"
    assert payload["message"] == "request failed"
    assert payload["status_code"] == 500


@pytest.mark.asyncio
async def test_main_health_uses_request_logging() -> None:
    from app.main import app

    stream = StringIO()
    setup_logging(app_env="test", log_level="INFO", stream=stream)
    transport = ASGITransport(app=app)

    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        response = await client.get("/health", headers={REQUEST_ID_HEADER: "req-main-health"})

    assert response.status_code == 200
    assert response.headers[REQUEST_ID_HEADER] == "req-main-health"
    payload = next(item for item in _payloads(stream) if item.get("logger") == "app.request")
    assert payload["message"] == "request completed"
    assert payload["path"] == "/health"
    assert payload["status_code"] == 200


def _settings(**kwargs: Any) -> Settings:
    settings_cls = cast(Any, Settings)
    return settings_cls(_env_file=None, **kwargs)


def _snapshot_logger(
    logger: logging.Logger,
) -> tuple[Sequence[logging.Handler], Sequence[Any], int, bool, bool]:
    return (
        list(logger.handlers),
        list(logger.filters),
        logger.level,
        logger.disabled,
        logger.propagate,
    )


def _restore_logger(
    logger: logging.Logger,
    state: tuple[Sequence[logging.Handler], Sequence[Any], int, bool, bool],
) -> None:
    handlers, filters, level, disabled, propagate = state
    logger.handlers = list(handlers)
    logger.filters = list(filters)
    logger.setLevel(level)
    logger.disabled = disabled
    logger.propagate = propagate


def _payloads(stream: StringIO) -> list[dict[str, Any]]:
    return [json.loads(line) for line in stream.getvalue().splitlines() if line.strip()]


def _single_payload(stream: StringIO) -> dict[str, Any]:
    payloads = _payloads(stream)
    assert len(payloads) == 1
    return payloads[0]
