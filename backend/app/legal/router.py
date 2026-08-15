"""법적 고지 공개 라우트.

사람이 직접 열어보는 공개 문서(Google Play 등록용 privacy policy URL 포함)라
``/api/v1`` prefix 없이 최상위로 등록한다 — ``app.shares.router.landing_router``와
같은 이유 (060-share-native-experience, 075-privacy-policy-page).
"""

from __future__ import annotations

from fastapi import APIRouter
from fastapi.responses import HTMLResponse

from app.auth.service import PRIVACY_CONSENT_VERSION

legal_router = APIRouter(tags=["legal"])

_EFFECTIVE_DATE = "2026-08-13"


def _render_privacy_policy_page() -> str:
    return f"""<!doctype html>
<html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>개인정보처리방침 — 다채로울지도</title></head>
<body style="font-family:sans-serif;max-width:640px;margin:0 auto;
    padding:32px 20px 64px;color:#1F1F1B;line-height:1.6;">
<h1 style="font-size:22px;">다채로울지도(ColorTrip) 개인정보처리방침</h1>
<p style="color:#666;font-size:13px;">시행일: {_EFFECTIVE_DATE}</p>

<p>다채로울지도(이하 "서비스")는 이용자의 개인정보를 소중히 다루며, 「개인정보 보호법」 등
관련 법령을 준수합니다. 본 방침은 서비스가 어떤 개인정보를 어떤 목적으로 수집·이용하는지
안내합니다.</p>

<h2 style="font-size:17px;margin-top:32px;">1. 수집하는 개인정보 항목</h2>
<table style="width:100%;border-collapse:collapse;font-size:14px;margin-top:8px;">
<tr style="background:#F0F0EA;">
  <th style="text-align:left;padding:8px;border:1px solid #E0E0DA;">구분</th>
  <th style="text-align:left;padding:8px;border:1px solid #E0E0DA;">수집 항목</th>
  <th style="text-align:left;padding:8px;border:1px solid #E0E0DA;">수집 목적</th>
</tr>
<tr>
  <td style="padding:8px;border:1px solid #E0E0DA;">회원가입/인증</td>
  <td style="padding:8px;border:1px solid #E0E0DA;">닉네임, 생년월일, 카카오 계정
    식별자, 프로필 이미지(선택)</td>
  <td style="padding:8px;border:1px solid #E0E0DA;">카카오 소셜 로그인 연동, 회원 식별,
    본인 확인, 프로필 표시</td>
</tr>
<tr>
  <td style="padding:8px;border:1px solid #E0E0DA;">위치정보</td>
  <td style="padding:8px;border:1px solid #E0E0DA;">기기의 위치 정보(GPS 등)</td>
  <td style="padding:8px;border:1px solid #E0E0DA;">여행 퀘스트의 방문 위치 인증</td>
</tr>
<tr>
  <td style="padding:8px;border:1px solid #E0E0DA;">카메라/사진</td>
  <td style="padding:8px;border:1px solid #E0E0DA;">촬영하거나 업로드한 사진</td>
  <td style="padding:8px;border:1px solid #E0E0DA;">여행 퀘스트의 사진 인증, 프로필 이미지
    등록</td>
</tr>
<tr>
  <td style="padding:8px;border:1px solid #E0E0DA;">서비스 이용 기록</td>
  <td style="padding:8px;border:1px solid #E0E0DA;">색칠한 지역, 진행률, 여행 성향(DNA)
    결과, 퀘스트 완료 이력</td>
  <td style="padding:8px;border:1px solid #E0E0DA;">서비스 제공, 개인화된 추천, 서비스
    개선</td>
</tr>
</table>

<h2 style="font-size:17px;margin-top:32px;">2. 개인정보의 보유 및 이용 기간</h2>
<p>이용자의 개인정보는 회원 탈퇴 시까지 보유하며, 탈퇴 시 지체 없이 파기합니다. 단, 관계
법령에서 별도의 보관 기간을 정하는 경우 그 기간 동안 보관합니다. 서비스는 앱 내
회원탈퇴 기능을 제공합니다.</p>

<h2 style="font-size:17px;margin-top:32px;">3. 개인정보의 제3자 제공 및 처리위탁</h2>
<p>서비스는 이용자의 개인정보를 원칙적으로 외부에 제공하지 않습니다. 다만 아래의 경우에
한해 위탁·연동합니다.</p>
<ul style="font-size:14px;">
  <li><strong>Kakao Corp.</strong> — 소셜 로그인 인증 처리</li>
  <li><strong>Google Cloud Platform</strong> — 서버 인프라 및 데이터 저장</li>
</ul>

<h2 style="font-size:17px;margin-top:32px;">4. 이용자의 권리</h2>
<p>이용자는 언제든지 자신의 개인정보를 열람·정정·삭제하거나 처리 정지를 요구할 수
있으며, 앱 내 회원탈퇴를 통해 개인정보 삭제를 요청할 수 있습니다.</p>

<h2 style="font-size:17px;margin-top:32px;">5. 문의처</h2>
<p>개인정보 처리에 관한 문의는 아래로 연락해 주세요.</p>
<p style="color:#999;font-size:13px;">담당자 연락처: rainbow.dev00@gmail.com</p>

<footer style="margin-top:48px;padding-top:16px;border-top:1px solid #E0E0DA;
    color:#999;font-size:12px;">
  버전: {PRIVACY_CONSENT_VERSION}
</footer>
</body></html>"""


@legal_router.get("/privacy", response_class=HTMLResponse)
async def get_privacy_policy_page() -> HTMLResponse:
    """개인정보처리방침 공개 페이지 (인증 불필요, Google Play 등록용 URL)."""
    return HTMLResponse(content=_render_privacy_policy_page())
