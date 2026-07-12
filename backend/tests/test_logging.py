from __future__ import annotations

import json
import logging
from datetime import UTC, datetime
from io import StringIO
from typing import Any, cast
from uuid import uuid4

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.core.config import Settings
from app.core.logging import (
    REQUEST_ID_HEADER,
    redact_sensitive_data,
    register_request_logging,
    resolve_log_level,
    setup_logging,
)


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
        "Authorization: Bearer access-token-123 "
        "access_token=kakao-token serviceKey=tour-key password=secret"
    )

    redacted = redact_sensitive_data(message)

    assert "access-token-123" not in redacted
    assert "kakao-token" not in redacted
    assert "tour-key" not in redacted
    assert "password=secret" not in redacted
    assert "[REDACTED]" in redacted


def test_setup_logging_reenables_existing_app_loggers() -> None:
    logger = logging.getLogger("app.request")
    logger.disabled = True
    stream = StringIO()

    setup_logging(app_env="test", log_level="INFO", stream=stream)
    logger.info("request completed", extra={"request_id": "req-reenabled"})

    payload = _single_payload(stream)
    assert payload["message"] == "request completed"
    assert payload["request_id"] == "req-reenabled"


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

    @app.get("/boom")
    async def boom() -> dict[str, str]:
        raise RuntimeError("boom")

    transport = ASGITransport(app=app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        response = await client.get("/boom", headers={REQUEST_ID_HEADER: "req-boom"})

    assert response.status_code == 500
    assert response.headers[REQUEST_ID_HEADER] == "req-boom"

    payload = _payloads(stream)[0]
    assert payload["severity"] == "ERROR"
    assert payload["message"] == "request failed"
    assert payload["request_id"] == "req-boom"
    assert payload["path"] == "/boom"
    assert payload["status_code"] == 500
    assert "exception" in payload


def _settings(**kwargs: Any) -> Settings:
    settings_cls = cast(Any, Settings)
    return settings_cls(_env_file=None, **kwargs)


def _payloads(stream: StringIO) -> list[dict[str, Any]]:
    return [json.loads(line) for line in stream.getvalue().splitlines() if line.strip()]


def _single_payload(stream: StringIO) -> dict[str, Any]:
    payloads = _payloads(stream)
    assert len(payloads) == 1
    return payloads[0]
