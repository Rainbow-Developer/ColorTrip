# [설명] 지도 채색 기준 — 퀘스트를 1개 이상 완료한 여행 수

## 개요

충북 11개 시·군 지도의 채색 진하기를 "그 지역에서 **퀘스트를 1개 이상 완료한 여행(여정) 수**"로 결정한다. 여행 중 첫 퀘스트를 인증한 순간부터 지역이 칠해지고, 같은 지역을 여러 번 여행할수록 진해진다(5회에 최대 채도).

채색은 여행의 진행 상태(`Journey.status`)와 **무관하다** — 여행이 진행 중이어도 인증이 1건 있으면 칠해지고, 여행을 완료해도 인증이 0건이면 칠해지지 않는다. 여행 완료 판정 규칙은 [010-journey](../010-journey/)를 참고한다.

## 동작 방식

1. 사용자가 여행에 담은 퀘스트 중 **하나라도** 인증에 성공하면, 그 여행이 채색 집계에 1회로 포함된다 (BE: `Journey ⨝ JourneyQuest ⨝ QuestProgress(completed)`의 `COUNT(DISTINCT Journey.id)`).
2. FE는 지역별 집계 값을 `max(서버 동기화 값, 로컬 누적값)`으로 계산한다.
3. 채도 = `집계 값 / 5` (0.0~1.0 클램프) → `ChungbukMap`이 회색→진녹색으로 5단계 양자화해 그린다.
4. 앱 진입 시 `GET /users/me/map` 응답의 `completed_journey_count`(= 채색 집계 값)로 서버 값을 동기화한다.

```mermaid
flowchart LR
    A["퀘스트 1개 인증 성공"] --> B["그 여행이 채색 집계에 포함"]
    B --> C["집계 값 (max(서버, 로컬))"]
    C --> D["채도 = min(1, n/5)"]
    D --> E[ChungbukMap 채색]
```

## 주요 구성 요소 / 위치

| 구성 요소 | 역할 | 위치 |
|-----------|------|------|
| 채색 집계 | region별 "완료 퀘스트 ≥ 1인 여행" COUNT | `backend/app/maps/repository.py` |
| 지도 응답 스키마 | `completed_journey_count` 필드(= 채색 집계 값) | `backend/app/maps/schemas.py` |
| 채도 계산 | `regionSaturation`, cap=5 | `frontend/lib/state/progress_state.dart` |
| 로컬 누적 | 지역 첫 퀘스트 완료 시 +1 (`localTripCompletions`) | `frontend/lib/state/progress_notifier.dart` |
| 서버 동기화 | map 응답 파싱·병합 | `frontend/lib/state/progress_notifier.dart`, `lib/data/repositories/map_repository.dart` |
| 지도 렌더링 | 채도→색 보간(기존 유지) | `frontend/lib/core/widgets/chungbuk_map.dart` |

## 설정 / 사용법

- 채도 기준선: `ProgressState._tripSaturationCap = 5` (상수).
- API: `GET /api/v1/users/me/map` → `data.regions[].completed_journey_count` — 이름은 유지하되 의미는 "채색으로 집계된 여행 수(완료 퀘스트 ≥ 1)"다.

## 예시

- 청주 여행에 퀘스트 5개를 담고 1개만 인증 → 청주 채도 20%(1단계).
- 같은 청주를 다시 여행하며 1개 인증 → 집계 2회 → 채도 40%(2단계) / 5회 이상 → 100%(5단계).
- 여행을 만들었지만 인증이 0건 → 미채색(회색). 여행을 완료 처리해도 마찬가지다.
- "완료 지역" 통계 = 집계 값 ≥ 1인 지역 수.

## 관련 문서

- [plan.md](plan.md) · [implementation.md](implementation.md)
- 여정 도메인: [docs/specs/010-journey/](../010-journey/)
