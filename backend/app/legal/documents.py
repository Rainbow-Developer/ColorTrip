"""Versioned legal documents rendered from verified deployment disclosures."""

# ruff: noqa: E501

from dataclasses import dataclass
from hashlib import sha256
from html import escape

from app.core.config import settings


@dataclass(frozen=True)
class LegalDocument:
    kind: str
    version: str
    effective_date: str
    title: str
    body: str

    @property
    def digest(self) -> str:
        return sha256(self.body.encode("utf-8")).hexdigest()


def _value(value: str) -> str:
    """Escape deployment-supplied facts before embedding them in public HTML."""
    normalized = value.strip()
    return escape(normalized) if normalized else "출시 전 설정 필요"


def _terms_body() -> str:
    operator_name = _value(settings.legal_operator_name)
    operator_email = _value(settings.legal_operator_email)
    operator_address = _value(settings.legal_operator_address)
    return f"""
<h1>다채로울지도(ColorTrip) 이용약관</h1>
<p>시행일: {_value(settings.legal_document_effective_date)}</p>
<h2>1. 목적과 운영자</h2>
<p>이 약관은 {operator_name}(이하 “운영자”)가 제공하는 다채로울지도 서비스의 이용 조건과
이용자 및 운영자의 권리·의무를 정합니다. 운영자 주소는 {operator_address}, 문의처는
{operator_email}입니다.</p>
<h2>2. 이용 자격과 계정</h2>
<p>서비스는 만 14세 이상만 이용할 수 있습니다. 이용자는 카카오 계정으로 로그인하며, 정확한
생년월일과 필수 동의 정보를 제공해야 합니다.</p>
<h2>3. 서비스와 이용자 콘텐츠</h2>
<p>서비스는 지역 탐방, 여행 성향 추천, 퀘스트 인증, 여행 기록 및 선택적 공유 기능을 제공합니다.
이용자가 올린 사진과 입력한 여행 정보에 대한 책임은 이용자에게 있으며, 타인의 권리·초상권·저작권을
침해하는 콘텐츠를 올려서는 안 됩니다.</p>
<h2>4. 금지행위와 이용 제한</h2>
<p>부정 인증, 타인 계정 사용, 서비스 장애 유발, 법령 위반 또는 권리 침해 행위는 금지됩니다.
운영자는 위반이 확인되면 이용을 제한하거나 콘텐츠를 삭제할 수 있습니다.</p>
<h2>5. 변경·책임·분쟁</h2>
<p>운영자는 서비스 또는 약관을 변경할 수 있으며 시행 전에 앱 또는 공개 페이지로 알립니다.
운영자와 이용자는 관련 법령에 따라 분쟁을 해결합니다.</p>
"""


def _privacy_body() -> str:
    operator_name = _value(settings.legal_operator_name)
    operator_email = _value(settings.legal_operator_email)
    operator_address = _value(settings.legal_operator_address)
    officer_name = _value(settings.legal_privacy_officer_name)
    officer_email = _value(settings.legal_privacy_officer_email)
    gcs_name = _value(settings.legal_gcs_processor_name)
    gcs_country = _value(settings.legal_gcs_processing_country)
    gcs_region = _value(settings.legal_gcs_region)
    gemini_name = _value(settings.legal_gemini_processor_name)
    gemini_country = _value(settings.legal_gemini_processing_country)
    gemini_retention = _value(settings.legal_gemini_retention_period)
    share_retention = _value(settings.legal_share_retention_period)
    aggregate_retention = _value(settings.legal_aggregate_retention_period)
    return f"""
<h1>다채로울지도(ColorTrip) 개인정보처리방침</h1>
<p>시행일: {_value(settings.legal_document_effective_date)}</p>
<h2>1. 개인정보처리자와 문의</h2>
<p>개인정보처리자는 {operator_name}이며, 주소는 {operator_address}, 일반 문의처는
{operator_email}입니다. 개인정보 보호책임자(또는 담당자)는 {officer_name}, 연락처는
{officer_email}입니다.</p>
<h2>2. 수집 항목·목적·법적 근거</h2>
<table><thead><tr><th>항목</th><th>목적</th><th>근거·보유 기간</th></tr></thead><tbody>
<tr><td>카카오 식별자, 닉네임, 카카오 프로필 이미지 URL</td><td>카카오 로그인, 계정 식별</td><td>정보주체 동의 및 서비스 이용계약 이행, 회원 탈퇴 시까지</td></tr>
<tr><td>생년월일</td><td>만 14세 이상 가입 자격 확인</td><td>정보주체 동의, 회원 탈퇴 시까지. 동의 거부 시 가입할 수 없습니다.</td></tr>
<tr><td>약관·방침 버전, 다이제스트, 동의 시각·출처</td><td>동의 사실과 문서 버전 증명</td><td>정보주체 동의, 회원 탈퇴 시까지</td></tr>
<tr><td>여행 성향 설문 응답·결과, 여정 제목·기간·지역·선택 퀘스트, 퀘스트 답변·완료 시각·지역 진행도</td><td>여행 추천, 기록, 지도 진행도 제공</td><td>정보주체 동의 및 서비스 이용계약 이행, 회원 탈퇴 시까지</td></tr>
<tr><td>프로필 사진·퀘스트 인증 사진</td><td>프로필 표시와 사진 퀘스트 인증</td><td>정보주체가 선택해 업로드, 탈퇴 시 삭제. 인증 실패 사진은 판정 후 삭제합니다.</td></tr>
<tr><td>공유 코드, 공유 시점의 닉네임·여행 성향·완료 지역·진행률</td><td>이용자가 생성한 공개 여행 카드 제공</td><td>정보주체의 공유 요청, {share_retention}</td></tr>
<tr><td>접속 토큰·refresh token 해시</td><td>로그인 세션 유지·보안</td><td>서비스 이용계약 이행, 토큰 만료 또는 철회 시까지</td></tr>
</tbody></table>
<h2>3. 위치정보</h2>
<p>GPS 인증을 위해 단말의 현재 위치 권한을 요청할 수 있습니다. 일반 GPS 퀘스트의 위도·경도는
단말에서만 거리 판정에 사용하고 서버로 전송하거나 저장하지 않습니다. 위치 권한을 거부하면 GPS 퀘스트
인증 기능을 이용할 수 없지만 다른 서비스 이용에는 영향을 주지 않습니다.</p>
<h2>4. 사진과 외부 처리</h2>
<p>사진에는 얼굴, 촬영 장소 또는 메타데이터 등 개인정보가 포함될 수 있습니다. 이용자는 타인의
개인정보를 포함한 사진을 업로드하기 전에 필요한 권한을 확보해야 합니다. 운영자는 사진 인증을 위해
{gemini_name}에 사진 바이트와 퀘스트 판정 문맥을 전송할 수 있습니다. 해당 처리 국가는
{gemini_country}, 보유·처리 기준은 {gemini_retention}입니다.</p>
<h2>5. 위탁·국외 이전</h2>
<p>사진 저장을 위해 {gcs_name}에 사진을 처리위탁·보관합니다. 처리 국가는 {gcs_country},
저장 리전은 {gcs_region}입니다. 사진 인증을 위해 {gemini_name}에 사진을 전송하며 처리 국가는
{gemini_country}입니다. 국외 이전은 서비스 이용계약의 체결·이행을 위하여 필요한 처리위탁 또는
보관을 근거로 하며, 이 방침으로 이전받는 자·국가·항목·목적·보유 기준을 공개합니다.</p>
<h2>6. 파기와 탈퇴 후 통계</h2>
<p>탈퇴 시 계정 식별 정보, 생년월일, 동의 기록, 사진 및 사진 URL을 삭제합니다. 여행 완료 수와
지역별 진행도 등 개인을 직접 식별하지 않는 집계 통계는 {aggregate_retention} 동안 보관합니다.
파일 삭제가 실패하면 오류 로그를 남기고 운영자가 후속 조치합니다.</p>
<h2>7. 이용자의 권리</h2>
<p>이용자는 앱에서 자신의 정보를 조회·정정하고 탈퇴할 수 있으며, {officer_email}로 열람·정정·삭제·처리정지
요구를 할 수 있습니다. 공개 공유 카드는 공유 기능에서 생성되며, 삭제 또는 철회를 요청할 수 있습니다.</p>
<h2>8. 변경과 고충처리</h2>
<p>이 방침을 변경할 때에는 시행일과 변경 내용을 공개합니다. 개인정보 관련 고충은 {officer_name}({officer_email})에게
접수할 수 있습니다.</p>
"""


TERMS = LegalDocument(
    "terms",
    settings.legal_terms_version,
    settings.legal_document_effective_date,
    "다채로울지도(ColorTrip) 이용약관",
    _terms_body(),
)
PRIVACY = LegalDocument(
    "privacy",
    settings.legal_privacy_version,
    settings.legal_document_effective_date,
    "다채로울지도(ColorTrip) 개인정보처리방침",
    _privacy_body(),
)
