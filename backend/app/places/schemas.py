"""places — 응답 스키마.

규약: docs/specs/090-realtime-tour-place-info/description.md
TourAPI 실패 시 필드를 null로 두고, 앱은 placeholder를 표시한다.
"""

from pydantic import BaseModel


class PlaceImage(BaseModel):
    """지역 화면 썸네일 매칭용 — TourAPI contentid → 대표 이미지 URL."""

    content_id: str
    image_url: str


class OperationInfo(BaseModel):
    """운영정보 — detailIntro2의 유형별 필드를 공통 이름으로 정규화한 값."""

    usetime: str | None = None
    restdate: str | None = None


class PlaceDetail(BaseModel):
    """상세 화면용 장소 정보 — 조회 실패한 항목은 null."""

    content_id: str
    image_url: str | None = None
    overview: str | None = None
    operation_info: OperationInfo | None = None
