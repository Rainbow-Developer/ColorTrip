from __future__ import annotations

import html

from fastapi import APIRouter, Depends, status
from fastapi.responses import HTMLResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import CurrentUser
from app.core.database import get_session
from app.core.exceptions import AppException
from app.core.response import Envelope, success
from app.shares import service
from app.shares.schemas import (
    ShareCreateRequest,
    ShareCreateResponse,
    ShareReadResponse,
    ShareStyle,
    ShareSummaryResponse,
)

router = APIRouter(tags=["shares"])

# 랜딩 페이지 전용 공개 라우트 — /api/v1 prefix 없이 최상위로 등록한다(사람이 직접 클릭하는
# 공개 URL이라 API 버전 prefix가 어울리지 않는다, 060-share-native-experience).
landing_router = APIRouter(tags=["shares"])

# 앱이 아직 스토어에 배포되지 않아 실제 URL이 없다. 배포 후 이 값을 채우면
# 랜딩 페이지에 "앱 다운받기" 링크가 활성화된다.
PLAY_STORE_URL = ""

REGION_NAMES = (
    "진천군",
    "음성군",
    "증평군",
    "청주시",
    "괴산군",
    "충주시",
    "제천시",
    "단양군",
    "보은군",
    "옥천군",
    "영동군",
)

DNA_DETAILS = {
    "nature": (
        "자연탐험형 여행자",
        "대자연 속에서 에너지를 얻고 조용한 힐링을 즐기는 탐험가예요.",
    ),
    "food": (
        "로컬 미식가",
        "지역의 맛으로 여행을 기억하는 타입이에요. 진짜 여행은 현지 맛집에서 시작되죠.",
    ),
    "history": (
        "이야기 수집가",
        "골목과 유적에 담긴 이야기를 모으는 타입이에요. 오래된 것에서 깊이를 발견하죠.",
    ),
    "activity": (
        "에너지 탐험가",
        "몸으로 부딪치며 즐기는 타입이에요. 가만히 있는 여행은 답답하죠.",
    ),
    "healing": (
        "느림의 여행자",
        "천천히 머무르며 충전하는 타입이에요. 여백이 있는 여행을 사랑하죠.",
    ),
}


@router.get("/users/me/share-summary", response_model=Envelope[ShareSummaryResponse])
async def get_my_share_summary(
    current_user: CurrentUser,
    session: AsyncSession = Depends(get_session),
) -> Envelope[ShareSummaryResponse]:
    """내 여행 지도 진행률, DNA, 색칠된 시·군 목록 요약 데이터를 조회합니다."""
    summary = await service.get_user_share_summary_data(session, current_user)
    return success(summary)


@router.post(
    "/shares",
    response_model=Envelope[ShareCreateResponse],
    status_code=status.HTTP_201_CREATED,
)
async def create_share_card(
    payload: ShareCreateRequest,
    current_user: CurrentUser,
    session: AsyncSession = Depends(get_session),
) -> Envelope[ShareCreateResponse]:
    """선택한 공유 스타일에 따른 숏코드 및 공유 URL을 생성합니다."""
    res = await service.create_share_card(session, current_user, payload)
    return success(res)


@router.get("/shares/{share_code}", response_model=Envelope[ShareReadResponse])
async def get_public_share_card(
    share_code: str,
    session: AsyncSession = Depends(get_session),
) -> Envelope[ShareReadResponse]:
    """외부 누구나 접속 가능한 공개 공유 카드 데이터를 조회합니다."""
    card_data = await service.get_public_share_card(session, share_code)
    return success(card_data)


def _render_not_found_page(share_code: str) -> str:
    safe_code = html.escape(share_code)
    return f"""<!doctype html>
<html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>존재하지 않는 공유 링크 — 다채로울지도</title></head>
<body style="font-family:sans-serif;text-align:center;padding:48px 16px;color:#4A4A44;">
<h1 style="font-size:20px;">존재하지 않는 공유 링크예요</h1>
<p>코드 <code>{safe_code}</code>에 해당하는 공유를 찾을 수 없어요.</p>
</body></html>"""


def _render_public_map(card: ShareReadResponse) -> str:
    if card.share_style not in {ShareStyle.MAP.value, ShareStyle.MAP_AND_DNA.value}:
        return ""

    colored_region_names = {region.name for region in card.colored_regions}
    cells = []
    for region_name in REGION_NAMES:
        is_colored = region_name in colored_region_names
        cell_style = (
            "background:#2D6A4F;color:#FFFFFF;border:1px solid #2D6A4F;"
            if is_colored
            else "background:#F5F4EE;color:#8B8A81;border:1px solid #E4E1D6;"
        )
        cells.append(
            '<div style="padding:10px 6px;border-radius:10px;text-align:center;'
            f'font-size:12px;font-weight:700;{cell_style}">'
            f"{html.escape(region_name)}</div>"
        )

    empty_state_html = (
        """
        <p style="margin:10px 0 0;color:#777;font-size:12px;text-align:center;">
            아직 색칠한 지역이 없어요.
        </p>
        """
        if not colored_region_names
        else ""
    )

    return f"""
        <section style="margin:18px 0;padding:16px;border:1px solid #E4E1D6;border-radius:16px;
                        background:#FCFBF6;">
            <div style="display:flex;justify-content:space-between;align-items:end;gap:12px;">
                <h2 style="font-size:15px;margin:0;color:#1F1F1B;">충북 여행 지도</h2>
                <span style="font-size:12px;color:#777;">색칠 {card.completed_region_count}곳</span>
            </div>
            <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin-top:12px;">
                {"".join(cells)}
            </div>
            {empty_state_html}
        </section>
    """


def _render_dna(card: ShareReadResponse) -> str:
    if card.share_style not in {ShareStyle.DNA.value, ShareStyle.MAP_AND_DNA.value}:
        return ""
    if not card.dna_name:
        return ""

    dna_title, dna_description = DNA_DETAILS.get(
        card.dna_type or "",
        (card.dna_name, "나만의 여행 취향으로 충북을 탐험하고 있어요."),
    )

    return f"""
        <section style="margin:18px 0;padding:16px;border:1px solid #D7E7C8;border-radius:16px;
                        background:#F4FAEE;">
            <div style="font-size:12px;color:#4F7A5E;font-weight:700;margin-bottom:6px;">
                여행 DNA
            </div>
            <h2 style="font-size:17px;margin:0;color:#1A5C35;">{html.escape(dna_title)}</h2>
            <p style="font-size:13px;line-height:1.55;color:#4A4A44;margin:8px 0 0;">
                {html.escape(dna_description)}
            </p>
        </section>
    """


def _render_share_landing_page(card: ShareReadResponse) -> str:
    nickname = html.escape(card.owner_nickname or "여행자")
    title = f"{nickname}님의 여행 지도"

    region_count_label = f"{card.completed_region_count}/{card.total_region_count}"
    stat_box_style = "font-size:18px;font-weight:700;"
    stats_html = f"""
        <div style="display:flex;justify-content:space-evenly;margin:16px 0;">
            <div><div style="font-size:12px;color:#888;">완료 지역</div>
                 <div style="{stat_box_style}">{region_count_label}</div></div>
            <div><div style="font-size:12px;color:#888;">진행률</div>
                 <div style="{stat_box_style}">{card.progress_percentage}%</div></div>
        </div>
    """

    map_html = _render_public_map(card)
    dna_html = _render_dna(card)

    open_app_url = f"colortrip://share/{html.escape(card.share_code)}"
    download_html = (
        f'<a href="{html.escape(PLAY_STORE_URL)}" '
        'style="display:block;background:#2D6A4F;color:#fff;text-decoration:none;'
        'padding:14px;border-radius:10px;font-weight:700;margin-top:8px;">앱 다운받기</a>'
        if PLAY_STORE_URL
        else '<div style="padding:14px;color:#999;font-size:13px;">앱 다운로드 (출시 예정)</div>'
    )

    return f"""<!doctype html>
<html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} — 다채로울지도</title></head>
<body style="font-family:sans-serif;max-width:420px;margin:0 auto;padding:24px 16px;color:#1F1F1B;">
<h1 style="font-size:18px;text-align:center;">{title}</h1>
{stats_html}
{map_html}
{dna_html}
<div style="margin-top:24px;">
    <a href="{open_app_url}"
       style="display:block;background:#EAF3DE;color:#1A5C35;text-decoration:none;
              padding:14px;border-radius:10px;font-weight:700;text-align:center;">앱에서 열기</a>
    <div style="text-align:center;">{download_html}</div>
    <p style="text-align:center;color:#999;font-size:12px;margin-top:16px;">
        앱 다운받고 퀘스트 깨러가기!
    </p>
</div>
</body></html>"""


@landing_router.get("/share/{share_code}", response_class=HTMLResponse)
async def get_share_landing_page(
    share_code: str,
    session: AsyncSession = Depends(get_session),
) -> HTMLResponse:
    """공유 링크를 클릭한 외부 사용자에게 보여주는 공개 HTML 랜딩 페이지.

    안드로이드 전용 — "앱에서 열기"는 사용자가 직접 탭하는 커스텀 URL 스킴 링크이며,
    앱 미설치 시 브라우저가 조용히 무시하고 이 페이지에 그대로 머문다(별도 폴백 불필요).
    """
    try:
        card = await service.get_public_share_card(session, share_code)
    except AppException:
        return HTMLResponse(content=_render_not_found_page(share_code), status_code=404)
    return HTMLResponse(content=_render_share_landing_page(card))
