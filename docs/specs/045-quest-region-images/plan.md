# [계획] 퀘스트·지역 이미지

| 항목 | 내용 |
|------|------|
| 기능명 | 퀘스트·지역 이미지 (TourAPI) |
| Spec 폴더 | `docs/specs/045-quest-region-images/` |
| 영역 | 공통 (frontend 중심 + backend 스크립트) |
| 작성자 | Claude Code (KAN-58) |
| 작성일 | 2026-07-30 |
| 상태 | 계획 |

## 배경 / 목적

앱 전반의 퀘스트·지역 표시가 회색 placeholder 박스와 이모지로 되어 있다. 정적 퀘스트 220개는 원래 TourAPI로 생성됐지만 이미지 URL·좌표를 dart 파일에 남기지 않았다. TourAPI의 대표 이미지(`firstimage`)와 좌표(`mapx/mapy`)를 정적 데이터에 보강해 실제 관광지 이미지를 보여준다. 좌표는 050(온디바이스 위치 인증)의 선행 조건이기도 하다.

## 목표 (Goals)

- 정적 퀘스트 데이터에 `imageUrl`·`lat`·`lng`를 보강하는 재실행 가능한 스크립트를 만든다.
- 지역(11개)에 대표 이미지(`imageUrl`)를 보강한다.
- 퀘스트 목록/상세/지역 화면의 placeholder를 실제 이미지로 교체한다(실패 시 기존 placeholder 폴백).

## 비목표 (Non-Goals)

- 이미지 자체 호스팅/캐싱 서버 구축 — TourAPI CDN URL을 그대로 사용.
- BE `Quest.thumbnail_url` 적재 로직 변경(loader가 이미 처리).

## 요구사항

- 이미지 없는 퀘스트는 기존 placeholder 유지(빈 URL 강제 금지).
- `verify == 'gps'` 퀘스트는 좌표가 반드시 채워져야 한다(누락 시 스크립트가 경고).
- 네트워크 이미지는 로딩·에러 상태를 처리한다(캐시 포함).

## 설계 개요 / 접근 방식

- **보강 스크립트** `backend/scripts/enrich_frontend_quests.py`(신규):
  1. `quests_data.dart`를 파싱해 (id, region, place, verify) 목록 추출.
  2. 지역별 `areaBasedList2`(contentTypeId 12/14/28/39, 생성 스크립트와 동일 호출)로 후보를 모아 **장소명 정규화 매칭** → `firstimage`/`mapx`/`mapy` 획득.
  3. 미매칭 장소(수제 퀘스트 등)는 `searchKeyword2`(sigunguCode 한정)로 보충.
  4. 각 `Quest(...)` 블록에 `imageUrl:`·`lat:`·`lng:` 필드를 삽입(이미 있으면 갱신 — 재실행 가능).
  5. `regions_data.dart`에는 지역 대표 명소(스크립트 내 curated 목록: 단양 도담삼봉 등)의 이미지를 `imageUrl:`로 삽입.
- **frontend**:
  - `Quest`에 `imageUrl`/`lat`/`lng`(nullable), `Region`에 `imageUrl`(nullable) 추가.
  - `cached_network_image` 도입, 공용 위젯 `lib/core/widgets/app_network_image.dart`(로딩 shimmer 대신 기존 placeholder 색, 에러 시 placeholder 폴백).
  - 적용 화면: `quest_list_screen`(리딩 썸네일), `quest_detail_screen`(헤더 이미지), `region_overview_screen`(지역 헤더+퀘스트 썸네일), `region_quest_select_screen`(썸네일). 홈 배너 이미지는 040에서 처리.

## 의사결정 (함께 논의 · 근거 필수)

| 결정할 항목 | 선택지 | 제안 / 근거 | 상태 |
|------|--------|------------|------|
| 이미지 소스 | TourAPI CDN 핫링크 / 에셋 번들 / 자체 스토리지 | **TourAPI CDN**(공공데이터 제공 URL)을 기본으로 사용한다. 단, 지역 개요의 브랜딩 목적 대표 이미지는 소수 로컬 asset 예외를 허용한다(KAN-100 단양군). 전체 퀘스트 이미지를 에셋 번들로 전환하는 것은 용량·수집 비용 때문에 비목표로 유지한다. | 합의됨(구현 승인, KAN-100 예외 추가) |
| 네트워크 이미지 패키지 | `Image.network` / `cached_network_image` | **cached_network_image**. 목록 스크롤에서 재다운로드 방지(디스크 캐시), 로딩·에러 빌더 일원화. Flutter 생태 표준으로 리스크 낮음 | 합의됨(구현 승인) |
| 정적 데이터 보강 방식 | dart 파일 재생성 / 필드 삽입 스크립트 | **필드 삽입**. 기존 생성 스크립트는 재실행 차단 가드가 있고 수제 퀘스트를 보존해야 함. 삽입 방식은 재실행 가능(idempotent) | 합의됨(구현 승인) |

## 영향 범위

- backend: `scripts/enrich_frontend_quests.py`(신규, 앱 코드 아님)
- frontend: `pubspec.yaml`(cached_network_image), `lib/data/models/quest.dart`, `lib/data/models/region.dart`, `lib/data/static/quests_data.dart`, `lib/data/static/regions_data.dart`, `lib/core/widgets/app_network_image.dart`(신규), quests 화면 4종
- 문서: README `패키지 의존성`(FE 표), [external-apis](../../conventions/external-apis.md)는 KorService2 기존 사용 범위 내(신규 신청 없음 — searchKeyword2 사용 추가만 표에 반영)

## 작업 단계

- [ ] 보강 스크립트 작성·실행 (TourAPI 일 1,000건 제한 내: 지역당 areaBased 4콜 + 키워드 보충 ≈ 100~300콜)
- [ ] FE 모델 필드 + 공용 이미지 위젯 + 화면 적용
- [ ] `flutter analyze`/`flutter test` 통과

## 리스크 / 미해결 질문

- TourAPI 이미지 URL이 http인 항목 존재 가능 → Android cleartext 정책 확인 필요(https 강제 변환 시도).
- 장소명 매칭 실패분은 이미지 없이 남는다(placeholder 폴백으로 수용).
