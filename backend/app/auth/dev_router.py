"""Local-only Kakao OAuth test pages."""

from html import escape
from urllib.parse import urlencode

from fastapi import APIRouter, Depends, Query
from fastapi.responses import HTMLResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import service
from app.auth.kakao import KakaoClient, get_kakao_client
from app.core.config import settings
from app.core.database import get_session
from app.core.exceptions import AppException

router = APIRouter(prefix="/dev", tags=["dev-auth"])

_STATE = "colortrip-local-dev"


@router.get("/kakao-login-test")
async def kakao_login_test() -> HTMLResponse:
    params = urlencode(
        {
            "response_type": "code",
            "client_id": settings.kakao_rest_api_key,
            "redirect_uri": settings.kakao_redirect_uri,
            "state": _STATE,
            "through_account": "true",
        }
    )
    authorize_url = f"{settings.kakao_authorize_url}?{params}"
    body = f"""
    <!doctype html>
    <html lang="ko">
      <head><meta charset="utf-8"><title>Kakao Login Test</title></head>
      <body>
        <h1>ColorTrip Kakao Login Test</h1>
        <a href="{escape(authorize_url)}">Kakao login</a>
      </body>
    </html>
    """
    return HTMLResponse(body)


@router.get("/kakao/callback")
async def kakao_callback(
    code: str | None = Query(None),
    state: str | None = Query(None),
    error: str | None = Query(None),
    error_description: str | None = Query(None),
    session: AsyncSession = Depends(get_session),
    kakao_client: KakaoClient = Depends(get_kakao_client),
) -> HTMLResponse:
    if error is not None:
        return _error_page(error_description or error, 400)
    if state != _STATE:
        return _error_page("Invalid OAuth state.", 400)
    if code is None:
        return _error_page("Missing authorization code.", 400)

    try:
        data = await service.login_with_kakao_authorization_code(
            session,
            authorization_code=code,
            kakao_client=kakao_client,
        )
    except AppException as exc:
        return _error_page(exc.message, exc.error.status)

    body = f"""
    <!doctype html>
    <html lang="ko">
      <head><meta charset="utf-8"><title>Kakao Login Success</title></head>
      <body>
        <h1>Login success</h1>
        <dl>
          <dt>User</dt><dd>{escape(str(data.user.id))}</dd>
          <dt>Access token</dt><dd><code>{escape(data.access_token)}</code></dd>
          <dt>Refresh token</dt><dd><code>{escape(data.refresh_token)}</code></dd>
        </dl>
      </body>
    </html>
    """
    return HTMLResponse(body)


def _error_page(message: str, status_code: int) -> HTMLResponse:
    body = f"""
    <!doctype html>
    <html lang="ko">
      <head><meta charset="utf-8"><title>Kakao Login Failed</title></head>
      <body>
        <h1>Login failed</h1>
        <p>{escape(message)}</p>
      </body>
    </html>
    """
    return HTMLResponse(body, status_code=status_code)
