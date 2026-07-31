# [설명] 지도 채색 기준 전환 — 완료 여행 수

## 개요

충북 11개 시·군 지도의 채색 진하기를 "그 지역에서 **완료한 여행(여정) 수**"로 결정한다. 여행을 한 번 완주하면 지역이 칠해지고, 같은 지역을 여러 번 여행할수록 진해진다(3회에 최대 채도).

## 동작 방식

1. 사용자가 지역 여행의 선택 퀘스트를 전부 완료하면 그 지역의 여행이 "완료" 상태가 된다 (FE `tripStatusOf`, BE `Journey.status='completed'`).
2. FE는 지역별 완료 여행 수를 `max(서버 동기화 값, 로컬 파생값 0/1)`로 계산한다.
3. 채도 = `완료 여행 수 / 3` (0.0~1.0 클램프) → `ChungbukMap`이 회색→진녹색으로 연속 보간해 그린다.
4. 앱 진입 시 `GET /users/me/map` 응답의 `completed_journey_count`로 서버 값을 동기화한다.

```mermaid
flowchart LR
    A[퀘스트 전부 완료] --> B[여행 완료 상태]
    B --> C["완료 여행 수 (max(서버, 로컬))"]
    C --> D["채도 = min(1, n/3)"]
    D --> E[ChungbukMap 채색]
```

## 주요 구성 요소 / 위치

| 구성 요소 | 역할 | 위치 |
|-----------|------|------|
| 완료 여정 집계 | region별 완료 Journey COUNT | `backend/app/maps/repository.py` |
| 지도 응답 스키마 | `completed_journey_count` 필드 | `backend/app/maps/schemas.py` |
| 채도 계산 | `regionSaturation`, cap=3 | `frontend/lib/state/progress_state.dart` |
| 서버 동기화 | map 응답 파싱·병합 | `frontend/lib/state/progress_notifier.dart`, `lib/data/repositories/map_repository.dart` |
| 지도 렌더링 | 채도→색 보간(기존 유지) | `frontend/lib/core/widgets/chungbuk_map.dart` |

## 설정 / 사용법

- 채도 기준선: `ProgressState._tripSaturationCap = 3` (상수).
- API: `GET /api/v1/users/me/map` → `data.regions[].completed_journey_count`.

## 예시

- 청주시 여행 1회 완료 → 채도 33% / 3회 이상 → 100%.
- "완료 지역" 통계 = 완료 여행 수 ≥ 1인 지역 수.

## 관련 문서

- [plan.md](plan.md) · [implementation.md](implementation.md)
- 여정 도메인: [docs/specs/010-journey/](../010-journey/)
