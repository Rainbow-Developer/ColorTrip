# [계획] 여행 관리

| 항목 | 내용 |
|------|------|
| 기능명 | 여행 관리 |
| Spec 폴더 | `docs/specs/085-journey-management/` |
| 영역 | backend / frontend |
| 작성자 | Codex |
| 작성일 | 2026-08-16 |
| 상태 | 완료 |

## 배경 / 목적
사용자는 여행을 시작한 뒤 여행명이나 일정을 잘못 입력할 수 있고, 테스트 또는 실수로 만든 여행을 정리하고 싶을 수 있다. 현재 앱은 여행 생성과 퀘스트 교체는 제공하지만 여행명·일정 수정과 여행 삭제 흐름이 없어 진행중/지난 여행 관리가 막혀 있다.

## 목표 (Goals)
- 여행 목록에서 여행명과 일정을 수정할 수 있다.
- 진행중/완료 여행 모두 삭제할 수 있다.
- 여행 삭제 시 해당 여행과 연결된 퀘스트 진행·완료 기록이 목록, 지도, 타임라인에서 사라진다.
- 기존 여행 카드 탭 동작과 퀘스트 수행 흐름은 유지한다.

## 비목표 (Non-Goals)
- 여행 지역 변경은 지원하지 않는다.
- 여행 삭제 후 복구 기능은 제공하지 않는다.
- 완료된 여행의 퀘스트 구성 변경 정책은 이번 범위에서 바꾸지 않는다.

## 요구사항
- 진행중/지난 여행 카드에서 관리 메뉴를 열 수 있어야 한다.
- 수정 시 기존 여행 시작 시트와 같은 입력 경험을 재사용한다.
- 삭제 전 확인 다이얼로그로 삭제 결과와 복구 불가를 안내한다.
- 백엔드는 본인 소유 여행만 수정·삭제할 수 있어야 한다.
- 삭제는 soft delete로 처리한다.

## 설계 개요 / 접근 방식
- Backend
  - `PATCH /journeys/{journey_id}`로 `title`, `start_date`, `end_date`를 갱신한다.
  - `DELETE /journeys/{journey_id}`로 여행, 여행-퀘스트 연결, 해당 여행에 연결된 퀘스트 진행 및 타임라인 이벤트를 soft delete한다.
- Frontend
  - `TripCard`에 선택적 액션 메뉴를 추가한다.
  - `TravelListScreen`에서 메뉴의 수정/삭제 콜백을 연결한다.
  - 여행 정보 입력 시트를 공용 위젯으로 분리해 생성과 수정에서 공유한다.

## 의사결정 (함께 논의 · 근거 필수)

| 결정할 항목 | 선택지 | 제안 / 근거 | 상태 |
|------|--------|------------|------|
| 삭제 범위 | 여행만 삭제 / 연결된 진행·완료 기록도 삭제 | 연결된 진행·완료 기록도 soft delete한다. 사용자에게는 “여행 삭제”가 그 여행 기록 정리로 인식되며, 지도 채색과 타임라인도 함께 정리되어야 일관된다. | 합의됨 |
| 삭제 가능 상태 | 진행중만 / 진행중+완료 | 진행중과 완료 모두 삭제 가능하게 한다. 잘못 만든 여행은 완료 여부와 무관하게 정리할 수 있어야 한다. | 합의됨 |
| 수정 가능 항목 | 이름만 / 이름+일정 / 이름+일정+퀘스트 | 이름+일정만 이번 범위로 둔다. 퀘스트 구성은 기존 선택 화면 흐름을 유지해 변경 범위를 줄인다. | 합의됨 |

## 영향 범위
- `backend/app/journeys/`
- `backend/tests/test_journey_flow.py`
- `frontend/lib/features/travel/`
- `frontend/lib/features/quests/region_quest_select_screen.dart`
- `frontend/lib/core/widgets/`
- `frontend/lib/data/repositories/domain_repository.dart`
- `frontend/lib/state/domain_controller.dart`
- `frontend/lib/state/progress_notifier.dart`
- `README.md`

## 작업 단계
- [x] 스펙 문서 작성
- [x] 백엔드 journey 수정/삭제 API 추가
- [x] 프론트 repository/controller 연결
- [x] 여행 카드 액션 메뉴와 수정/삭제 UI 추가
- [x] 검증 및 PR 업데이트

## 리스크 / 미해결 질문
- `quest_progress`는 사용자+퀘스트 단위라 동일 퀘스트 완료 기록을 다른 여행에서도 공유할 수 있다. 삭제 다이얼로그에서 진행·완료 기록 삭제를 명확히 고지한다.
