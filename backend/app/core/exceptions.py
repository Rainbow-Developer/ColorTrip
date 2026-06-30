"""공통 에러코드와 예외 핸들러 (Envelope로 일괄 변환).

규약: docs/conventions/api-design.md — HTTP status + 내부 코드(SUCCESS / NOT_FOUND_ERROR 등)
"""

from enum import Enum

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException


class ErrorCode(Enum):
    """(code, http_status, 기본 message)."""

    NOT_FOUND_ERROR = ("NOT_FOUND_ERROR", 404, "대상을 찾을 수 없습니다.")
    UNAUTHORIZED_ERROR = ("UNAUTHORIZED_ERROR", 401, "인증이 필요합니다.")
    TOKEN_EXPIRED_ERROR = ("TOKEN_EXPIRED_ERROR", 401, "토큰이 만료되었습니다.")
    SOCIAL_AUTH_ERROR = ("SOCIAL_AUTH_ERROR", 401, "소셜 인증에 실패했습니다.")
    VALIDATION_ERROR = ("VALIDATION_ERROR", 422, "요청 값이 올바르지 않습니다.")
    INTERNAL_ERROR = ("INTERNAL_ERROR", 500, "서버 오류가 발생했습니다.")

    def __init__(self, code: str, status: int, message: str):
        self.code = code
        self.status = status
        self.message = message


class AppException(Exception):
    """도메인에서 발생시키는 애플리케이션 예외."""

    def __init__(self, error: ErrorCode, message: str | None = None):
        self.error = error
        self.message = message or error.message
        super().__init__(self.message)


def _body(code: str, status: int, message: str) -> dict:
    return {"code": code, "status": status, "message": message, "data": None}


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppException)
    async def _handle_app(_: Request, exc: AppException) -> JSONResponse:
        return JSONResponse(
            status_code=exc.error.status,
            content=_body(exc.error.code, exc.error.status, exc.message),
        )

    @app.exception_handler(RequestValidationError)
    async def _handle_validation(_: Request, __: RequestValidationError) -> JSONResponse:
        e = ErrorCode.VALIDATION_ERROR
        return JSONResponse(status_code=e.status, content=_body(e.code, e.status, e.message))

    @app.exception_handler(StarletteHTTPException)
    async def _handle_http(_: Request, exc: StarletteHTTPException) -> JSONResponse:
        code = "NOT_FOUND_ERROR" if exc.status_code == 404 else "HTTP_ERROR"
        message = exc.detail if isinstance(exc.detail, str) else "요청을 처리할 수 없습니다."
        return JSONResponse(
            status_code=exc.status_code, content=_body(code, exc.status_code, message)
        )
