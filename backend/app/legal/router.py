"""Public legal-document routes."""

from html import escape
from urllib.parse import quote

from fastapi import APIRouter
from fastapi.responses import HTMLResponse

from app.core.config import settings
from app.legal.documents import PRIVACY, TERMS, LegalDocument

legal_router = APIRouter(tags=["legal"])


def _render(document: LegalDocument) -> str:
    return (
        '<!doctype html><html lang="ko"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        f"<title>{document.title}</title></head>"
        '<body style="font-family:sans-serif;max-width:640px;margin:0 auto;padding:32px 20px 64px;line-height:1.6;">'  # noqa: E501
        f'{document.body}<footer style="margin-top:48px;padding-top:16px;border-top:1px solid #ddd;color:#666;font-size:12px;">'  # noqa: E501
        f"버전: {escape(document.version)}<br>문서 다이제스트: {document.digest}"
        "</footer></body></html>"
    )


@legal_router.get("/terms", response_class=HTMLResponse)
async def get_terms_page() -> HTMLResponse:
    return HTMLResponse(content=_render(TERMS))


@legal_router.get("/privacy", response_class=HTMLResponse)
async def get_privacy_policy_page() -> HTMLResponse:
    return HTMLResponse(content=_render(PRIVACY))


@legal_router.get("/account-deletion", response_class=HTMLResponse)
async def get_account_deletion_page() -> HTMLResponse:
    operator_name = escape(settings.legal_operator_name.strip())
    officer_email = escape(settings.legal_privacy_officer_email.strip())
    aggregate_retention = escape(settings.legal_aggregate_retention_period.strip())
    account_subject = quote("ColorTrip 계정 삭제 요청")
    data_subject = quote("ColorTrip 일부 데이터 삭제 요청")
    body = f"""
<h1>다채로울지도(ColorTrip) 계정 및 데이터 삭제</h1>
<p>개발자: {operator_name}</p>
<h2>앱에서 계정 삭제하기</h2>
<ol><li>다채로울지도 앱을 엽니다.</li><li><strong>프로필</strong>로 이동합니다.</li>
<li><strong>회원 탈퇴</strong>를 선택하고 안내에 따라 확인합니다.</li></ol>
<h2>앱을 사용할 수 없을 때 계정 삭제 요청</h2>
<p><a href="mailto:{officer_email}?subject={account_subject}">{officer_email}</a>로
계정 삭제 요청 메일을 보내주세요. 사용 중인 닉네임과 요청 내용을 적어주시면 본인 확인을
안내합니다. 카카오 비밀번호, 인증번호 또는 액세스 토큰은 보내지 마세요. 본인 확인 완료 후
10일 이내 처리 결과를 안내합니다.</p>
<h2>계정을 유지하고 일부 데이터 삭제하기</h2>
<p>프로필 사진은 앱의 프로필 편집에서 삭제할 수 있습니다. 그 밖의 데이터는
<a href="mailto:{officer_email}?subject={data_subject}">{officer_email}</a>로
일부 데이터 삭제 요청을 보내주세요.</p>
<h2>삭제되는 데이터</h2>
<ul><li>카카오 계정 식별 정보, 닉네임, 생년월일</li>
<li>약관·개인정보처리방침 동의 기록과 로그인 토큰</li>
<li>프로필 사진과 퀘스트 인증 사진 및 사진 URL</li></ul>
<h2>보존되는 데이터</h2>
<p>개인을 직접 식별하지 않는 여행 완료 수와 지역별 진행도 등의 집계 통계는
{aggregate_retention} 보존합니다.</p>
<p><a href="/privacy">개인정보처리방침 보기</a></p>
"""
    return HTMLResponse(
        content=(
            '<!doctype html><html lang="ko"><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width, initial-scale=1">'
            "<title>다채로울지도 계정 및 데이터 삭제</title></head>"
            '<body style="font-family:sans-serif;max-width:640px;margin:0 auto;'
            f'padding:32px 20px 64px;line-height:1.6;">{body}</body></html>'
        )
    )
