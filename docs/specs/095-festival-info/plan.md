# [계획] 지역 행사·축제 정보

| 항목 | 내용 |
|------|------|
| 기능명 | 지역 행사·축제 정보 |
| Spec 폴더 | `docs/specs/095-festival-info/` |
| 영역 | 공통 (frontend 먼저, backend 후속) |
| 작성자 | Claude (AI) |
| 작성일 | 2026-08-21 |
| 상태 | 계획 |

## 배경 / 목적

* 팀 컨벤션은 [행사·축제 데이터를 TourAPI 행사정보로 쓰기로 결정](../../conventions/external-apis.md)했으나 아직 미구현이다 — 결정과 구현의 간극을 메운다.
* 여행자가 지역을 볼 때 "지금 가면 뭐가 열리나"를 함께 보여줘 방문 동기를 높인다.

## 목표 (Goals)

* 지역(시·군) 화면에 진행 중 행사·축제 섹션(가로 스크롤 카드: 포스터·행사명·기간·D-day)을 표시한다.
* 행사가 없으면 섹션 자체를 렌더링하지 않는다(빈 박스 없음).
* 프론트를 먼저 완성해 APK로 시연한다 — 데이터 계층은 인터페이스 뒤에 두고 스텁으로 시작한다.

## 비목표 (Non-Goals)

* 백엔드 `searchFestival2` 프록시 — 이번 단계에서 구현하지 않는다(후속 단계, 아래 작업 단계 2단계). 프록시가 생기면 [090](../090-realtime-tour-place-info/)과 같은 방식(서버가 키를 들고 실시간 조회)으로 붙인다.
* 행사 상세 화면·알림·즐겨찾기 — 첫 버전은 카드 나열까지만.
* 행사 데이터 저장·캐싱 — 090과 같은 실시간 원칙을 따른다.

## 요구사항

* 데이터 접근은 `FestivalRepository` 인터페이스로 추상화하고, 스텁 구현은 지역별 실존 축제 샘플을 반환한다(시연용임을 코드 주석에 명시).
* 포스터 이미지는 TourAPI CDN URL 형태를 가정하고 기존 `AppNetworkImage`로 로드한다(로딩·실패 시 placeholder).
* 백엔드 전환 시 provider override 교체만으로 동작해야 한다(화면 코드 수정 없음).

## 설계 개요 / 접근 방식

* **모델** `Festival`: id·title·placeName·startDate·endDate·posterUrl.
* **저장소** `FestivalRepository.byRegion(String regionId)` → `Future<List<Festival>>`. 첫 구현은 `StubFestivalRepository`(정적 샘플, 오늘 날짜 기준 진행 중만 반환).
* **상태** `regionFestivalsProvider` — `FutureProvider.autoDispose.family<List<Festival>, String>`(090의 place providers와 같은 패턴).
* **화면** 지역 개요 화면(`region_overview_screen.dart`) 히어로 아래 `FestivalSection` 위젯: 가로 스크롤 카드(포스터 16:9·행사명·기간 `M.d~M.d`·D-day 배지). 로딩·실패·빈 결과 → 섹션 숨김.
* **백엔드(후속)**: `GET /api/v1/festivals?region_slug=` 프록시(searchFestival2, `eventStartDate` 필수 파라미터) — 별도 작업 단계로 분리.

## 의사결정 (함께 논의 · 근거 필수)

| 결정할 항목 | 선택지 | 제안 / 근거 | 상태 |
|------|--------|------------|------|
| 표시 위치 | 지역 화면 섹션 / 홈 섹션 / 별도 탭 | **지역 화면 섹션** — 행사는 지역 종속 데이터(searchFestival2도 지역 단위 조회)라 맥락이 자연스럽고, 탭을 늘리지 않는다 | 합의됨 |
| 첫 단계 데이터 | 스텁 샘플 / 백엔드 프록시 동시 구현 | **스텁 샘플로 프론트 먼저** — APK 시연이 목적이고, 인터페이스 뒤에 두면 백엔드 전환이 override 교체로 끝난다(090에서 검증된 패턴) | 합의됨 |
| 빈 상태 처리 | 섹션 숨김 / "행사 없음" 문구 | **섹션 숨김** — 행사 없는 지역이 다수일 때 빈 문구가 반복 노출되는 것보다 깔끔 | 합의됨 |

## 영향 범위

* **frontend**: `data/models/festival.dart`(신설) · `data/repositories/festival_repository.dart`(신설) · `state/repository_providers.dart` · `features/quests/region_overview_screen.dart` · `test/`
* **backend**: 없음(후속 단계에서 `app/festivals/` 또는 `app/places/` 확장)
* **문서**: `docs/specs/README.md` 인덱스, README 주요 기능 표(백엔드 연동 완료 시)

## 작업 단계

- [ ] 1단계(이번): 모델·저장소 인터페이스·스텁·provider·FestivalSection UI + 테스트, APK 시연
- [ ] 2단계(후속): 백엔드 searchFestival2 프록시 + Dio 구현체 교체 + 스텁 제거

## 리스크 / 미해결 질문

* 스텁 샘플은 날짜가 지나면 "진행 중" 필터에 걸려 안 보일 수 있다 — 샘플 기간을 넉넉히 잡고, 2단계 전환 전까지의 임시 상태임을 스텁 주석에 명시한다.
* searchFestival2의 응답 필드(포스터 `firstimage` 여부 등)는 2단계에서 실호출로 검증한다 — 모델 필드는 그때 조정될 수 있다.
