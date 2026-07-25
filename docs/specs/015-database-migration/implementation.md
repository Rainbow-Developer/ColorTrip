# [구현 수준] PR #15 Database.md Alembic 마이그레이션

| 항목 | 내용 |
|------|------|
| 상태 | 구현 완료 / KAN-52 Alembic head 정합화 완료 |
| 최종 업데이트 | 2026-07-25 |

## 구현 규모 / 단위 분할

- **규모 판단**: 단위로 나눠 구현 — PR #15 DB 범위는 기존 auth/quest 테이블 보강, 신규 도메인 모델, Alembic revision, 테스트 fixture, API 후속 이슈화가 함께 얽혀 있어 순서 있는 검증이 필요하다.
- **구현 단위**:
  - [x] 1) 기준 문서와 현재 DB 컨벤션 차이 분석.
  - [x] 2) 스펙 문서와 API 후속 기록 작성.
  - [x] 3) migration schema regression 테스트 추가.
  - [x] 4) ORM 모델과 Alembic env metadata import 추가.
  - [x] 5) Alembic revision 작성 및 downgrade 경로 구현.
  - [x] 6) fixture reset 로직 갱신.
  - [x] 7) Alembic 왕복 검증, Ruff, Pyright, Pytest 실행.
  - [x] 8) API 후속 GitHub Issue 생성 및 문서 반영.
  - [x] 9) PR #17 Journey 스키마를 PR #15 `database.md`와 migration regression test에 반영.
  - [x] 10) 단일-head 회귀 테스트를 추가하고 현재 복수 head에서 실패함을 확인.
  - [x] 11) KAN-52에서 병렬 생성된 두 Alembic head를 merge revision으로 통합.
  - [x] 12) 세 가지 기존 DB head 상태의 전환, 전체 backend 테스트, Ruff, Pyright를 검증.

## 구현된 항목

- PR #15 DDL을 현재 ColorTrip DB 컨벤션으로 변환하는 기준을 정리했다.
- API 후속 작업 후보를 `api-followups.md`에 기록했다.
- `backend/app/core/enums.py`에 lowercase `DnaType` 값을 추가했다.
- `users` ORM에 `dna`, `profile_image` 컬럼을 추가했다.
- `quest_progress`, `map_progress`, `timeline_events`, `trip_questions`, `trip_question_options`, `trip_replies`, `user_dna_history` ORM 모델을 추가했다.
- Alembic `a4f2c8d1e9b0_add_pr15_database_spec_tables.py` revision을 추가했다.
- `quest_progress.status`, `map_progress.completed_count`는 ORM default와 DB server default를 함께 가진다.
- `quest_progress.status` CHECK 제약 추가 전 기존 데이터에 허용되지 않은 상태값이 있는지 명시적으로 검사한다.
- `timeline_events`, `trip_replies`, `user_dna_history`의 사용자별 시간순 조회 인덱스는 PR #15 조회 의도에 맞춰 시간 컬럼 DESC 정렬을 명시한다.
- 테스트 DB reset 로직이 현재 schema를 재생성한 뒤 `upgrade head` 하도록 갱신했다.
- `backend/tests/test_database_spec_schema.py`로 PR #15 스키마 핵심 계약, DB server default, 신규 ORM 모델 insert 기본값을 검증한다.
- PR #17의 `f4b2a9c67e18`이 `journeys`, `journey_quests`, `quest_progress.journey_id`, `quest_progress.quiz_answer`를 생성하고, PR #24의 `a4f2c8d1e9b0`이 그 위에 이어짐을 문서화했다.
- `backend/tests/test_database_spec_schema.py`가 Journey 테이블, FK, unique 제약, 진행 확장 컬럼을 회귀 검증한다.
- `backend/tests/test_migration_graph.py`가 Alembic revision graph의 head가 정확히 하나인지 검증한다.
- `be3e3c52de66_merge_alembic_heads.py`가 `5eab7d8363e0`, `c9d4e7a2b8f3`을 빈 DDL mergepoint로 통합한다.
- PostgreSQL `colortrip_test`에서 한쪽 sibling만 적용된 두 경우와 두 sibling이 모두 적용된 경우가 `be3e3c52de66` 단일 version row로 수렴함을 검증했다.
- 공통 부모 `9c0244355f03`까지 downgrade한 뒤 다시 head로 upgrade하는 왕복을 검증했다.
- 전체 backend 테스트 92개, Ruff check, 변경 파일 format check, Pyright를 통과했다.
- 기존 구현된 API 수정 필요 지점만 GitHub Issue로 유지했다:
  - [#18](https://github.com/Rainbow-Developer/ColorTrip/issues/18): 사용자 프로필 응답의 `dna`/`profile_image` 반영 검토.
  - [#20](https://github.com/Rainbow-Developer/ColorTrip/issues/20): 기존 퀘스트 조회 응답의 진행 상태 반영 검토.
  - [#21](https://github.com/Rainbow-Developer/ColorTrip/issues/21): 기존 지역 목록 응답의 지도 진행 정보 반영 검토.

## 미구현 / 남은 항목

- 이번 migration PR 범위의 DB/ORM/Alembic 구현은 완료했다.
- PR #15 머지 이후 변경되는 DB/API 요구사항은 후속 revision으로 보정한다.
- API 구현은 `api-followups.md`에 연결된 GitHub Issue에서 진행한다.

## 알려진 한계 / TODO

- 설문 질문/선택지 seed 데이터는 아직 포함하지 않는다.
- Journey migration은 이미 PR #17에서 적용됐다. 같은 테이블을 생성하는 추가 revision은 만들지 않으며, 이후 schema 변경이 필요할 때만 `a4f2c8d1e9b0` 뒤 새 revision을 추가한다.
- API 구현은 이번 migration PR 범위에서 제외하고 GitHub Issue로 분리한다.
- mergepoint에서 상대 단계 `downgrade -1`은 모호하므로, 롤백할 때 공통 부모 등 명시적인 revision을 지정해야 한다.
- dev 배포 경로는 Alembic migration을 자동 실행하지 않는다. KAN-52에서는 graph만 정합화하고 배포 자동화는 후속 작업으로 분리한다.

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-07-08 | PR #15 database.md 우선 Alembic 마이그레이션 스펙 최초 작성 |
| 2026-07-08 | ORM 모델, Alembic revision, schema regression 테스트, API 후속 GitHub Issue 연결 |
| 2026-07-08 | DB server default, DESC index, ORM insert 기본값 검증 보강 |
| 2026-07-12 | CodeRabbit 검토 후 enum 중복 제거, 테스트 DB reset 스키마 재생성, quest_progress 상태값 preflight 보강 |
| 2026-07-16 | PR #17 Journey 스키마를 PR #15 `database.md`에 반영하고 Alembic 체인 회귀 검증 보강 |
| 2026-07-25 | KAN-52 복수 Alembic head를 빈 merge revision으로 통합하는 계획 추가 |
| 2026-07-25 | `be3e3c52de66` merge revision과 단일-head 회귀 테스트 추가, 세 가지 기존 DB 상태 전환 및 전체 품질 검증 완료 |
