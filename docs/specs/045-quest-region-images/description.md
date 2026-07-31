# [설명] 퀘스트·지역 이미지

## 개요

퀘스트와 지역에 한국관광공사 TourAPI의 대표 이미지(`firstimage`)를 연결해, 앱의 회색 placeholder를 실제 관광지 사진으로 바꾼다. 이미지 URL과 좌표는 보강 스크립트가 정적 데이터(dart)에 채워 넣고, 화면은 공용 네트워크 이미지 위젯으로 표시한다.

## 동작 방식

1. `backend/scripts/enrich_frontend_quests.py`가 TourAPI(`areaBasedList2`·`searchKeyword2`)에서 장소별 `firstimage`·`mapx/mapy`를 찾아 `quests_data.dart`·`regions_data.dart`에 `imageUrl`/`lat`/`lng` 필드를 삽입한다(재실행 가능).
2. 화면은 `AppNetworkImage`(cached_network_image 래퍼)로 URL을 로드한다. 로딩 중·실패·URL 없음 → 기존 placeholder 색 박스 유지.
3. 좌표는 050 위치 인증(온디바이스 거리 계산)의 입력으로도 사용된다.

## 주요 구성 요소 / 위치

| 구성 요소 | 역할 | 위치 |
|-----------|------|------|
| 보강 스크립트 | TourAPI 매칭·dart 필드 삽입 | `backend/scripts/enrich_frontend_quests.py` |
| 퀘스트/지역 모델 | `imageUrl`·`lat`·`lng` 필드 | `frontend/lib/data/models/quest.dart`, `region.dart` |
| 공용 이미지 위젯 | 캐시·로딩·에러 폴백 | `frontend/lib/core/widgets/app_network_image.dart` |
| 적용 화면 | 목록·상세·지역 화면 썸네일/헤더 | `frontend/lib/features/quests/` 4개 화면 |

## 설정 / 사용법

```bash
cd backend
uv run python scripts/enrich_frontend_quests.py   # TOUR_API_KEY 필요(.env)
```

- 스크립트는 idempotent — 이미 필드가 있으면 값을 갱신한다.
- 실행 후 `dart format`·`flutter analyze`로 검증한다.

## 예시

`Quest(id: 'dy2', ... imageUrl: 'https://tong.visitkorea.or.kr/cms/resource/.../123_image2_1.jpg', lat: 36.98, lng: 128.42, ...)`

매칭에 실패한 장소("OO 시내"처럼 TourAPI에 대응 관광지가 없는 경우)는 필드 없이 남아 기존 placeholder로 표시된다.

## 관련 문서

- [plan.md](plan.md) · [implementation.md](implementation.md)
- TourAPI 규약: [docs/conventions/external-apis.md](../../conventions/external-apis.md)
