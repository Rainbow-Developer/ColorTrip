"""Versioned legal-document metadata."""

from dataclasses import dataclass
from hashlib import sha256


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


TERMS = LegalDocument(
    "terms", "terms-v2", "2026-08-15", "다채로울지도(ColorTrip) 이용약관",
    "<h1>다채로울지도(ColorTrip) 이용약관</h1><p>시행일: 2026-08-15</p>"
    "<h2>이용 자격</h2><p>서비스는 만 14세 이상만 이용할 수 있습니다.</p>"
    "<h2>서비스 이용</h2><p>이용자는 카카오 계정을 이용하며 타인의 권리를 침해하거나 "
    "서비스를 부정하게 이용해서는 안 됩니다.</p><h2>문의</h2><p>문의와 분쟁은 관련 법령에 따라 처리합니다.</p>",  # noqa: E501
)
PRIVACY = LegalDocument(
    "privacy", "privacy-v2", "2026-08-15", "다채로울지도(ColorTrip) 개인정보처리방침",
    "<h1>다채로울지도(ColorTrip) 개인정보처리방침</h1><p>시행일: 2026-08-15</p>"
    "<h2>수집 항목과 목적</h2><p>카카오 계정 식별자, 닉네임, 생년월일, 동의 기록을 "
    "계정 식별과 만 14세 이상 확인을 위해 처리합니다. 프로필 이미지와 인증 사진은 선택 항목입니다.</p>"  # noqa: E501
    "<h2>보유와 파기</h2><p>계정 정보와 성공 인증 사진은 탈퇴 시 삭제하며, 실패 인증 사진은 "  # noqa: E501
    "판정 직후 삭제합니다.</p><h2>처리위탁</h2><p>카카오 로그인, Google Cloud 저장소 및 Gemini 사진 판정은 "  # noqa: E501
    "서비스 제공에 필요한 범위에서 처리합니다. 실제 처리 국가와 수탁자 정보는 공개 출시 전에 확정하여 고지합니다.</p>"  # noqa: E501
    "<h2>이용자 권리</h2><p>이용자는 앱 내 탈퇴 또는 운영자 문의처를 통해 열람·정정·삭제를 요청할 수 있습니다.</p>",  # noqa: E501
)
