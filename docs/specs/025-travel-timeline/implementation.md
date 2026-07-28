# [구현 수준] 여행 타임라인 API

| 항목 | 내용 |
|------|------|
| 상태 | 진행 중 (백엔드·Flutter 연동 완료 / KAN-55 실제 E2E 진행 중) |
| 최종 업데이트 | 2026-07-28 |

## 구현 규모 / 단위 분할
- **규모 판단**: 단위로 나눠 구현
- **구현 단위**:
  - [x] **1) DB 모델 및 마이그레이션**: `timelines` 모델과 Alembic migration 적용
  - [x] **2) 레포지토리 및 서비스 계층 개발**: 완료 트랜잭션에서 타임라인·지역 색칠 이벤트 적재
  - [x] **3) API 라우터 및 스키마 개발**: `GET /users/me/timeline`과 연/월 필터 구현
  - [x] **4) 통합 테스트 작성 및 검증**: 빈 목록, 완료 이벤트 생성, 연/월 필터 검증
  - [x] **5) Flutter 연동**: 서버 타임라인 조회·오류·재시작 복원 상태 연결 — [040](../040-domain-state-persistence/)

## 구현된 항목
- `timelines` 모델·repository·service·router
- 퀘스트 완료 시 `quest_completed`, 최초 지역 색칠 시 `region_colored` 이벤트 생성
- `GET /api/v1/users/me/timeline?year=&month=` 최신순 조회
- 복원용 `quest_id`·`quest_client_key`·`photo_url` 응답과 완료 이벤트 중복 방지 제약
- migration에서 기존 중복 완료 이벤트를 가장 이른 한 건으로 수렴한 뒤 유일 제약 적용
- Flutter 서버 snapshot 조회와 `TimelineScreen` 호환 projection
- `backend/tests/test_timeline.py` 통합 테스트

## 미구현 / 남은 항목
- [ ] 실제 Kakao 계정으로 앱 재시작·재로그인 후 타임라인 복원 E2E 확인

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-07-20 | 최초 계획 수립 및 문서 작성 |
| 2026-07-28 | 실제 백엔드 구현·테스트 완료 상태로 정정하고 Flutter 연동을 040에 연결 |
| 2026-07-28 | KAN-55에서 복원 식별자·중복 방지와 Flutter snapshot 연동 완료. 실제 계정 E2E는 진행 중 |
