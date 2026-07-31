# [계획] 지도 채색 기준 전환 — 완료 여행 수

| 항목 | 내용 |
|------|------|
| 기능명 | 지도 채색 기준 전환 (완료 퀘스트 개수 → 완료 여행 수) |
| Spec 폴더 | `docs/specs/035-journey-map-coloring/` |
| 영역 | 공통 (backend + frontend) |
| 작성자 | Claude Code (KAN-58) |
| 작성일 | 2026-07-30 |
| 상태 | 구현 완료 (2026-07-31) |

## 배경 / 목적

현재 지도 채색 진하기는 지역별 **완료 퀘스트 개수**(`MapProgress.completed_count`, FE `regionProgress`)를 기준선(6개)으로 나눈 비율이다. 제품 방향은 "여행(여정)을 완주할수록 그 지역이 진해지는" 경험이므로, 채색 기준을 **그 지역에서 완료한 여행(여정) 수**로 바꾼다.

## 목표 (Goals)

- 지역 채도 = `완료한 여행 수 / 기준선(cap)` 으로 산출한다 (FE·BE 동일 정의).
- `GET /users/me/map` 응답에 지역별 완료 여정 수(`completed_journey_count`)를 추가한다.
- 홈 "완료 지역" 통계를 "여행을 1회 이상 완료한 지역 수"로 재정의한다.

## 비목표 (Non-Goals)

- `MapProgress`(완료 퀘스트 수) 테이블·필드 제거 — 기존 필드는 유지(하위호환, 다른 통계에서 사용).
- 여행(journeys) 도메인 자체의 동작 변경.
- FE 정적 퀘스트의 BE 연동 전환.

## 요구사항

- 완료 여행이 0인 지역은 미채색(회색), 1회부터 채색 시작, cap 이상이면 최대 채도.
- FE는 비로그인/서버 미접속에서도 로컬 여행 완료 상태로 채색이 동작해야 한다(기존 낙관적 갱신 유지).
- 서버 동기화 시 서버 값이 로컬 파생값보다 크면 서버 값을 쓴다.

## 설계 개요 / 접근 방식

- **backend**: `app/maps/repository.py`에 `Journey(status='completed', deleted_at IS NULL)`를 `region_id`로 GROUP BY 집계하는 쿼리를 추가하고, `app/maps/schemas.py`의 `MapProgressRead`에 `completed_journey_count: int`(기본 0)를 추가한다. 기존 `completed_count`(퀘스트 수)는 그대로 내려준다.
- **frontend**:
  - `MapRegionProgress` 모델에 `completedJourneyCount` 파싱 추가(`map_repository`).
  - `ProgressState`에 서버 동기화용 `regionTripCount`와 로컬 누적 완주 횟수 `localTripCompletions`(둘 다 `Map<String,int>`)를 둔다. 표시용 완료 여행 수 = `max(서버값, 로컬 누적값)`.
  - 로컬 누적값은 **완주 시점에** `ProgressNotifier.completeQuest`가 1씩 올린다. 현재 선택 집합의 완주 여부로 파생하지 않는 이유: 완료한 지역에 퀘스트를 더 담으면(KAN-46 재방문) 선택 집합이 다시 미완료가 되어 이미 칠한 채색이 사라진다.
  - `regionSaturation` = `(완료 여행 수 / _tripSaturationCap).clamp(0,1)`, `_tripSaturationCap = 3`.
  - `completedRegionCount` = 완료 여행 수 ≥ 1인 지역 수.

## 의사결정 (함께 논의 · 근거 필수)

| 결정할 항목 | 선택지 | 제안 / 근거 | 상태 |
|------|--------|------------|------|
| 채도 기준선(cap) | 지역별 상대 비율 / 고정 cap N | **고정 cap 3**. 기존 퀘스트 기준도 지역별 비율의 편차 문제로 고정 cap(6)을 썼다(progress_state.dart 주석). 여행 1회 ≈ 퀘스트 여러 개이므로 6보다 낮은 3이 체감상 비슷한 진행 속도. 상수 하나라 조정 쉬움 | 합의됨(구현 승인) |
| 완료 지역 통계 의미 | 채도 100% 지역 / 여행 1회 이상 지역 | **여행 1회 이상 완료한 지역**. "완료 지역"의 직관(한 번이라도 완주)과 일치. 채도 100%(3회) 기준은 과도하게 엄격 | 합의됨(구현 승인) |
| 로컬·서버 병합 규칙 | 서버 우선 덮어쓰기 / max 병합 | **max 병합**. FE 정적 퀘스트 완료는 서버에 기록되지 않으므로 서버 우선 덮어쓰기 시 로컬 채색이 사라진다 | 합의됨(구현 승인) |
| 로컬 완주 값 산출 | 현재 선택 집합 완주 여부 파생 / 완주 시점 누적 | **완주 시점 누적**(`localTripCompletions`). 파생 방식은 완료 지역에 퀘스트를 추가할 때 선택 집합이 다시 미완료가 되어 채색이 0으로 되돌아간다(검증에서 발견). 누적이면 재방문 완주도 자연히 2회로 센다 | 합의됨(구현 중 변경) |

## 영향 범위

- backend: `app/maps/repository.py`, `app/maps/service.py`, `app/maps/schemas.py`, `tests/test_map_flow.py`
- frontend: `lib/state/progress_state.dart`, `lib/state/progress_notifier.dart`, `lib/state/map_sync_provider.dart`, `lib/data/models/map_region_progress.dart`, `lib/data/repositories/map_repository.dart`, `lib/features/home/home_screen.dart`(통계), `lib/core/widgets/map_legend.dart`(범례 문구)
- 문서: README `주요 기능과 위치`는 변화 없음(위치 동일), 본 spec이 SOT

## 작업 단계

- [x] BE: 완료 여정 수 집계 쿼리 + 응답 필드 + 테스트
- [x] FE: 모델·동기화 파싱 + 채도/통계 로직 교체 + 위젯 테스트
- [x] FE: 로컬 누적 완주 카운터(`localTripCompletions`) + 재방문 회귀 테스트
- [x] 범례·통계 라벨 확인 (범례 "여행 완료 횟수 0회 ~ 3회+")

## 리스크 / 미해결 질문

- 로컬 누적값은 메모리 상태라 앱 재시작 시 초기화된다(서버 동기화 값은 재조회). 영속화는 후속 과제.
- (해소) "로컬 단독은 0/1로 제한" 제약은 완주 시점 누적 방식으로 바꿔 없어졌다 — 같은 지역 재방문 완주도 2회로 센다.
