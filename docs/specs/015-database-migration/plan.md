# [계획] PR #15 Database.md Alembic 마이그레이션

| 항목 | 내용 |
|------|------|
| 기능명 | PR #15 Database.md Alembic 마이그레이션 |
| Spec 폴더 | `docs/specs/015-database-migration/` |
| 영역 | backend |
| 작성자 | Database Migration 담당 |
| 작성일 | 2026-07-08 |
| 상태 | 구현 완료 / KAN-52 Alembic head 정합화 완료 |

## 배경 / 목적

PR #15의 `docs/template/specs/database.md`에는 여행 DNA, 퀘스트 진행, 지도 진행, 타임라인까지 이어지는 ColorTrip 핵심 데이터 모델이 정리되어 있다. 이후 PR #17이 Journey 도메인(`journeys`, `journey_quests`, 확장된 `quest_progress`)을 추가했고, PR #24는 그 migration 위에 PR #15 나머지 모델을 이어 붙였다.

이번 정합화 작업의 우선순위는 **이미 적용된 Alembic 체인을 중복 생성하지 않고, DB 기준 문서와 회귀 테스트를 실제 구현에 맞추는 것**이다. PR #15의 literal DDL은 현재 저장소 규약과 일부 다르므로 그대로 적용하지 않고, UUID v7 PK, SQLAlchemy ORM 기본값, `deleted_at` soft delete, 기존 auth/quest 필드 보존 원칙을 따른다.

## 목표 (Goals)

| ID | 목표 |
|----|------|
| DB-01 | 기존 migration graph를 보존하고 모든 분기가 최종적으로 하나의 head로 수렴하는지 검증 |
| DB-02 | 기존 테이블 `users`, `refresh_tokens`, `regions`, `quests`의 현재 기능 필드를 유지하면서 필요한 컬럼만 보강 |
| DB-03 | `journeys`, `journey_quests`, `quest_progress.journey_id`, `quest_progress.quiz_answer`를 PR #15 `database.md`에 반영 |
| DB-04 | `dna_type` PostgreSQL enum 추가 및 관련 ORM 타입 정렬 |
| DB-05 | 신규 FK, unique, index를 migration과 ORM에 명시 |
| DB-06 | 테스트 fixture가 신규 테이블까지 Alembic reset을 안전하게 수행하고 Journey schema 계약을 검증 |
| DB-07 | API 후속 작업 후보를 문서화하고 구현 완료 후 GitHub Issue로 연결 |
| DB-08 | 동일 부모에서 갈라진 최신 revision을 merge revision으로 합쳐 `upgrade head`와 전체 DB 테스트를 복구 |

## 비목표 (Non-Goals)

- DNA/설문, 퀘스트 인증, 지도 진행, 타임라인 API 구현.
- 이미 존재하는 Journey 테이블을 다시 생성하는 별도 Alembic revision 추가.
- PR #15의 `BIGINT IDENTITY`, `gen_random_uuid()`, `is_deleted` 설계를 그대로 적용.
- 운영 데이터 마이그레이션이나 seed 데이터 확정.
- 프론트엔드 화면/상태 연동.

## 요구사항

**기능**
- PR #15 `database.md`에 PR #17 Journey 테이블과 `quest_progress` 확장 컬럼을 반영한다.
- `users.dna`, `users.profile_image` 컬럼을 추가하되, 기존 `withdrawal_grace_until`, `anonymized_at`을 유지한다.
- `refresh_tokens.token_hash` unique index를 유지한다.
- `regions.center_lat`, `regions.center_lng`, `quests.content_type_id`, `quests.lat`, `quests.lng`, `quests.verify_radius`를 유지한다.
- Journey 관련 테이블과 진행/설문/타임라인 테이블은 UUID PK와 공통 감사 컬럼을 가진다.

**비기능**
- 모든 테이블/컬럼명은 snake_case를 따른다.
- PK는 앱 레벨 UUID v7 기본값을 따른다.
- 삭제 상태는 `deleted_at`으로 통일하고 `is_deleted`는 추가하지 않는다.
- 시간 컬럼은 기존 KST 저장 규약과 `TimestampMixin`을 따른다.
- Alembic upgrade/downgrade가 `d7b712f1a245` 기준으로 `f4b2a9c67e18`과 `a4f2c8d1e9b0`을 포함해 왕복 가능해야 한다.
- 저장소에는 Alembic head가 항상 하나만 존재해야 한다. 일반 신규 migration은 그 단일 head를 부모로 삼아야 하며, 병렬 branch를 수렴시키는 merge revision은 의도적으로 여러 부모를 가질 수 있다.

## 설계 개요 / 접근 방식

```mermaid
flowchart TD
    A["PR #15 database.md"] --> B["Journey 스키마 정합화"]
    B --> C["f4b2a9c67e18 Journey revision"]
    C --> D["a4f2c8d1e9b0 PR #15 revision"]
    D --> E["PostgreSQL test DB upgrade/downgrade 검증"]
    B --> F["Journey schema regression test"]
```

- 기존 테이블은 additive migration만 수행한다.
- `f4b2a9c67e18`이 Journey 테이블과 `quest_progress` 확장 컬럼을 만들고, `a4f2c8d1e9b0`이 그 위에서 PR #15 모델을 보강한다.
- `quest_progress`는 사용자×퀘스트 단일 진행 row를 유지하고, 선택적 `journey_id`로 수행 여정을 추적한다.
- `trip_questions`, `trip_question_options`, `trip_replies`, `user_dna_history`는 설문과 DNA 산출 API의 기반으로 둔다.
- API 후속 작업은 이번 PR에서 구현하지 않고, 생성된 DB 기반과 실제 필요 범위를 재검토한 뒤 GitHub Issue로 분리한다.
- KAN-52에서는 `9c0244355f03`에서 갈라진 `5eab7d8363e0`과 `c9d4e7a2b8f3`을 부모로 갖는 빈 merge revision을 추가한다. 기존 revision의 DDL과 revision ID는 변경하지 않는다.
- `ScriptDirectory.get_heads()`가 정확히 한 개를 반환하는 회귀 테스트를 추가해 이후 병렬 PR이 복수 head를 다시 만들면 테스트 단계에서 탐지한다.
- PostgreSQL 테스트 DB에서 `5eab7d8363e0`만 적용, `c9d4e7a2b8f3`만 적용, 두 head 모두 적용된 상태를 각각 만든 뒤 `upgrade head`가 merge revision으로 수렴하는지 검증한다.

## 의사결정 (함께 논의 · 근거 필수)

| 결정할 항목 | 선택지 | 결정 / 근거 | 상태 |
|------|--------|------------|------|
| PR #15 DDL 적용 방식 | literal 적용 / 현 컨벤션 변환 | **현 컨벤션 변환** — 현재 `dev`는 UUID v7, `TimestampMixin`, `deleted_at` soft delete를 단일 규약으로 사용한다. BIGINT와 `is_deleted`를 섞으면 기존 모델과 테스트가 흔들린다. | 합의됨 |
| DNA 값 저장 | uppercase enum / lowercase enum | **lowercase enum** — 기존 `Category` 값과 API/퀘스트 카테고리 값이 `nature`, `food`, `history`, `activity`, `healing`으로 통일되어 있다. | 합의됨 |
| 진행 테이블과 Journey 관계 | 독립 진행 / `journey_id` 연결 | **`quest_progress` + 선택적 `journey_id`** — 사용자×퀘스트 진행의 유일성은 유지하고, 인증이 어느 여정에서 수행됐는지만 연결한다. PR #17 구현과 PR #24 migration이 이 구조를 이미 사용한다. | 합의됨 |
| soft delete 표시 | `deleted_at`만 / `is_deleted` 병행 | **`deleted_at`만** — DB 컨벤션과 기존 mixin을 따른다. 중복 상태값은 정합성 비용이 커진다. | 합의됨 |
| API 구현 포함 여부 | migration과 함께 구현 / 후속 이슈화 | **후속 이슈화** — 기존 auth/regions/quests API 안정성을 유지하고, DB 기반이 확정된 뒤 API를 작은 단위로 구현한다. | 합의됨 |
| 복수 head 해소 방식 | 기존 revision 재작성 / 빈 merge revision 추가 | **빈 merge revision 추가** — 이미 팀원·공유 환경에 적용됐을 수 있는 migration 이력을 보존하면서 두 분기를 단일 head로 수렴시킨다. | 합의됨 (KAN-52) |

## 영향 범위

- `backend/app/core/enums.py`: DNA enum 추가.
- `backend/app/auth/models.py`: `users.dna`, `users.profile_image` 추가.
- `backend/app/quests/models.py`: `quest_progress` 모델 추가.
- `backend/app/journeys/models.py`: `journeys`, `journey_quests` 모델 추가.
- `backend/app/progress/`: `map_progress` 모델 추가.
- `backend/app/timeline/`: `timeline_events` 모델 추가.
- `backend/app/trip_dna/`: 설문/DNA 모델 추가.
- `backend/alembic/env.py`: 신규 모델 metadata import 추가.
- `backend/alembic/versions/f4b2a9c67e18_add_journey_and_quest_progress_tables.py`: Journey schema migration.
- `backend/alembic/versions/a4f2c8d1e9b0_add_pr15_database_spec_tables.py`: PR #15 migration.
- `backend/alembic/versions/be3e3c52de66_merge_alembic_heads.py`: `5eab7d8363e0`, `c9d4e7a2b8f3` merge revision.
- `backend/tests/test_migration_graph.py`: Alembic graph가 항상 단일 head인지 DB 연결 없이 검증.
- `backend/tests/test_database_spec_schema.py`: Journey migration schema 회귀 검증.
- `docs/specs/015-database-migration/`: 계획/설명/구현/API 후속 기록.
- `docs/specs/README.md`, `README.md`: 새 스펙과 주요 기능 위치 반영.

## 작업 단계

- [x] PR #15 `database.md`와 현재 `dev`의 DB 컨벤션 차이 분석.
- [x] `docs/specs/015-database-migration/` 문서 작성.
- [x] `api-followups.md`에 API 후속 후보 기록.
- [x] 스키마 regression 테스트 추가.
- [x] ORM 모델 추가/수정.
- [x] Alembic env import 추가.
- [x] 기존 Alembic 체인 `f4b2a9c67e18` → `a4f2c8d1e9b0` 검증(중복 Journey revision 미추가).
- [x] 테스트 fixture DB reset 로직 갱신.
- [x] Alembic upgrade/downgrade와 품질 게이트 검증.
- [x] API 후속 GitHub Issue 생성 및 문서 반영.
- [x] PR #17 Journey 테이블과 `quest_progress` 확장 컬럼을 `database.md`에 반영.
- [x] Journey migration 체인과 FK/unique/index 회귀 검증을 추가.
- [x] KAN-52 단일-head 회귀 테스트를 먼저 추가하고 현재 복수 head에서 실패함을 확인.
- [x] Alembic CLI로 merge revision을 생성하고 단일 head·전체 backend 테스트를 검증.
- [x] PostgreSQL 테스트 DB의 세 가지 기존 head 상태에서 `upgrade head` 전환을 검증.

## 리스크 / 미해결 질문

- PR #15의 API 문서 일부는 `users.dna` 값을 uppercase로 설명한다. 이번 DB는 lowercase enum으로 정렬하므로 API 구현 시 응답 값 정책을 다시 확정해야 한다.
- Journey 스키마는 이미 `f4b2a9c67e18`에서 반영됐고 `a4f2c8d1e9b0`이 그 위에 이어진다. 같은 테이블을 다시 만드는 revision은 upgrade 실패를 유발하므로 추가하지 않는다.
- 설문 seed 데이터는 아직 확정되지 않았다. 컨벤션상 seed는 migration에 포함할 수 있으나, 이번 작업에서는 구조만 준비한다.
- 운영 DB에 이미 데이터가 있는 경우 신규 non-null 테이블 생성은 문제가 없지만, 기존 테이블에 non-null 컬럼을 추가하지 않는 원칙을 유지해야 한다.
- merge revision은 스키마 DDL을 실행하지 않는다. 한쪽 head만 적용된 DB는 `upgrade head` 시 누락된 sibling revision을 먼저 적용하고, 두 head가 모두 적용된 DB는 merge revision만 기록한다.
- mergepoint는 부모가 두 개라 `alembic downgrade -1` 대상이 모호해 `Ambiguous walk`로 거부된다. 롤백은 `alembic downgrade 9c0244355f03`처럼 공통 부모 revision을 명시한다.
- 현재 dev 배포 workflow와 `deploy.sh`는 Alembic migration을 자동 실행하지 않는다. KAN-52는 migration graph 수정에 한정하고, dev Cloud SQL 적용은 별도 운영 명령 또는 후속 배포 자동화 작업으로 수행한다.
