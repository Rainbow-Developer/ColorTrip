"""quests — API 라우터.

규약: docs/conventions/api-design.md (/api/v1 + 복수형 kebab, Offset page/size)
조회(목록·상세)는 공개, 추천·진행·인증은 보호 API(Bearer 토큰) — docs/specs/010-journey/.
※ /quests/recommended는 /quests/{quest_id}보다 먼저 선언해야 한다(경로 매칭 순서).
"""

from uuid import UUID

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import CurrentUser
from app.core.database import get_session
from app.core.enums import Category, ProgressStatus
from app.core.exceptions import AppException, ErrorCode
from app.core.response import Envelope, success
from app.quests import service, static_map
from app.quests.schemas import (
    ProgressItem,
    ProgressListData,
    QuestDetail,
    QuestListData,
    QuestStartRequest,
    QuestVerifyRequest,
    RecommendedListData,
    VerifyResultData,
)

router = APIRouter(prefix="/quests", tags=["quests"])
progress_router = APIRouter(prefix="/users/me", tags=["quests"])


@router.get("")
async def list_quests(
    region_id: UUID | None = None,
    category: Category | None = None,
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
    session: AsyncSession = Depends(get_session),
) -> Envelope[QuestListData]:
    data = await service.list_quests(session, region_id, category, page, size)
    return success(data)


@router.get("/recommended")
async def list_recommended_quests(
    current_user: CurrentUser,
    region_id: UUID | None = None,
    category: Category | None = None,
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
    session: AsyncSession = Depends(get_session),
) -> Envelope[RecommendedListData]:
    data = await service.list_recommended(session, current_user.id, region_id, category, page, size)
    return success(data)


@router.get("/{quest_id}")
async def get_quest(
    quest_id: UUID,
    session: AsyncSession = Depends(get_session),
) -> Envelope[QuestDetail]:
    quest = await service.get_quest_detail(session, quest_id)
    return success(QuestDetail.model_validate(quest))


@router.get(
    "/{quest_id}/map",
    response_class=Response,
    responses={200: {"content": {"image/png": {}}}},
)
async def get_quest_map(
    quest_id: UUID,
    session: AsyncSession = Depends(get_session),
) -> Response:
    """GPS 인증 화면의 지도 배경 (docs/specs/050-quest-verification, KAN-90).

    **퀘스트 좌표로만** 지도를 만든다 — 사용자 위치는 이 경로에 오지 않는다(좌표 비전송
    불변식). 내 위치는 단말이 이 이미지 위에 오버레이로 그린다.

    배경은 참고용이라 실패를 인증 실패로 번지게 하지 않는다. 좌표가 없거나 키 미설정·상류
    오류면 404를 주고 앱은 배경 없이 오버레이만 그린다(fail-soft).
    """
    quest = await service.get_quest_detail(session, quest_id)
    if quest.lat is None or quest.lng is None:
        raise AppException(ErrorCode.NOT_FOUND_ERROR, "이 퀘스트에는 좌표가 없습니다.")

    try:
        image = await static_map.fetch_quest_map(float(quest.lat), float(quest.lng))
    except static_map.StaticMapUnavailable as exc:
        raise AppException(ErrorCode.NOT_FOUND_ERROR, "지도 배경을 제공할 수 없습니다.") from exc

    # 퀘스트 좌표는 고정이라 오래 캐시해도 안전하다. 줌·크기를 바꾸면 URL이 아니라 서버
    # 캐시 키가 바뀌므로, 클라이언트 캐시는 짧게 두고 서버 캐시에 의존한다.
    return Response(
        content=image,
        media_type="image/png",
        headers={"Cache-Control": "public, max-age=86400"},
    )


@router.post("/{quest_id}/start", status_code=201)
async def start_quest(
    quest_id: UUID,
    current_user: CurrentUser,
    payload: QuestStartRequest | None = None,
    session: AsyncSession = Depends(get_session),
) -> Envelope[ProgressItem]:
    journey_id = payload.journey_id if payload else None
    data = await service.start_quest(session, current_user.id, quest_id, journey_id)
    return success(data, status=201, message="퀘스트를 시작했습니다.")


@router.post("/{quest_id}/verify")
async def verify_quest(
    quest_id: UUID,
    payload: QuestVerifyRequest,
    current_user: CurrentUser,
    session: AsyncSession = Depends(get_session),
) -> Envelope[VerifyResultData]:
    data = await service.verify_quest(session, current_user.id, quest_id, payload)
    message = "퀘스트를 완료했습니다." if data.verified else "인증에 실패했습니다."
    return success(data, message=message)


@progress_router.get("/progress")
async def list_my_progress(
    current_user: CurrentUser,
    status: ProgressStatus | None = None,
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
    session: AsyncSession = Depends(get_session),
) -> Envelope[ProgressListData]:
    data = await service.list_my_progress(session, current_user.id, status, page, size)
    return success(data)
