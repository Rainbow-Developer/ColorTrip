"""Public legal-document routes."""

from fastapi import APIRouter
from fastapi.responses import HTMLResponse

from app.legal.documents import PRIVACY, TERMS, LegalDocument

legal_router = APIRouter(tags=["legal"])


def _render(document: LegalDocument) -> str:
    return (
        '<!doctype html><html lang="ko"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        f"<title>{document.title}</title></head>"
        '<body style="font-family:sans-serif;max-width:640px;margin:0 auto;padding:32px 20px 64px;line-height:1.6;">'  # noqa: E501
        f'{document.body}<footer style="margin-top:48px;padding-top:16px;border-top:1px solid #ddd;color:#666;font-size:12px;">'  # noqa: E501
        f"버전: {document.version}<br>문서 다이제스트: {document.digest}</footer></body></html>"
    )


@legal_router.get("/terms", response_class=HTMLResponse)
async def get_terms_page() -> HTMLResponse:
    return HTMLResponse(content=_render(TERMS))


@legal_router.get("/privacy", response_class=HTMLResponse)
async def get_privacy_policy_page() -> HTMLResponse:
    return HTMLResponse(content=_render(PRIVACY))
