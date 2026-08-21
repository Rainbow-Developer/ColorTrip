"""사진 판정 프롬프트 빌더 — 퀘스트 맥락(제목·장소·조건)을 판정 지시문으로 만든다."""

# 장소 소개문이 길면 프롬프트만 비대해진다 — 판정 맥락으로 충분한 길이로 자른다.
_OVERVIEW_MAX_CHARS = 300


def build_photo_judgement_prompt(
    title: str, place: str, conditions: list[str], place_overview: str | None = None
) -> str:
    """비전 모델에 보낼 판정 프롬프트를 생성한다.

    응답은 JSON {passed, confidence, reason} 형식을 강제한다
    (VisionVerdict로 파싱 — reason은 한국어 한두 문장).
    place_overview는 TourAPI에서 실시간 조회한 장소 소개문(KAN-102) — 없으면 생략한다.
    """
    lines = [
        "당신은 여행 퀘스트의 사진 인증 심사관입니다.",
        "첨부된 사진이 아래 퀘스트의 인증 조건을 충족하는지 판정하세요.",
        "",
        f"퀘스트 제목: {title}",
    ]
    # 장소명은 서버 퀘스트 데이터에 없을 수 있다(KAN-73 — 판정 맥락을 서버가 만든다).
    if place.strip():
        lines.append(f"장소: {place}")
    if place_overview and place_overview.strip():
        lines.append(f"장소 소개: {place_overview.strip()[:_OVERVIEW_MAX_CHARS]}")
    if conditions:
        lines.append("인증 조건:")
        lines.extend(f"- {condition}" for condition in conditions)
    lines += [
        "",
        "사진만으로 정확한 장소를 단정하기 어렵다면, 사진의 내용이 퀘스트 맥락(장소의 유형·"
        "활동·분위기)과 부합하는지를 기준으로 관대하게 판정하세요.",
        "반드시 아래 형식의 JSON 객체 하나로만 답하세요:",
        '{"passed": <boolean>, "confidence": <0과 1 사이 숫자>, "reason": "<한국어 한두 문장>"}',
    ]
    return "\n".join(lines)
