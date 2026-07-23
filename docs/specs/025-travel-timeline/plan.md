# [계획] 여행 타임라인 API 구현

| 항목 | 내용 |
|------|------|
| 기능명 | 여행 타임라인 API |
| Spec 폴더 | `docs/specs/025-travel-timeline/` |
| 영역 | backend |
| 작성자 | Antigravity (AI) |
| 작성일 | 2026-07-20 |
| 상태 | 계획 |

## 배경 / 목적
* 사용자가 퀘스트를 완료하거나 지역 지도를 최초로 색칠했을 때, 그 발자취를 시간 순으로 기록하고 노출하기 위한 **여행 타임라인** 기능이 필요합니다.
* 우선 이를 서빙할 백엔드 데이터베이스 테이블을 설계하고, 타임라인 기록 적재 로직 및 프론트엔드 연동용 조회 API를 구축합니다.

## 목표 (Goals)
* 타임라인 이벤트를 저장하기 위한 `timeline` 테이블 설계 및 Alembic 마이그레이션 적용.
* **이벤트 기록**: 퀘스트 성공 완료(`quest_completed`) 및 지역 최초 색칠(`region_colored`) 시점에 자동으로 타임라인 레코드가 생성되는 백엔드 적재 파이프라인 연동.
* **조회 API**: 특정 유저의 타임라인 역사를 연/월별 헤더 및 지역명과 함께 최신순으로 제공하는 API 개발 (`GET /api/v1/users/me/timeline`).
* 데이터가 대용량으로 쌓였을 때의 조회 성능 최적화 (인덱스 적용).

## 비목표 (Non-Goals)
* 프론트엔드 (Flutter) UI/UX 화면 개발 (이번 단계는 오직 백엔드 API 연동 스펙만 우선 구축).
* 소셜 공유용 타임라인 피드 공유 기능 (추후 스펙).

## 요구사항
* **타임라인 조회 API (`GET /api/v1/users/me/timeline`)**
  * 인증된 사용자의 타임라인 목록을 반환해야 함.
  * 최신순(`occurred_at DESC`) 정렬.
  * 퀘스트 정보(퀘스트명 등) 및 지역 정보(시·군 명칭)가 조인되어 응답 데이터에 포함되어야 함.
* **타임라인 기록 연동**
  * 퀘스트 인증 심사가 통과되어 완료될 때 `quest_completed` 타입 이벤트 자동 생성.
  * 퀘스트 성공으로 인해 해당 시·군이 최초로 색칠(`is_colored`가 True로 전환)되는 트리거 시점에 `region_colored` 타입 이벤트 자동 생성.

## 설계 개요 / 접근 방식
* **테이블 명세 (`timeline`)**:
  * `id`: BIGINT, PK (auto)
  * `user_id`: BIGINT, FK -> users
  * `region_id`: BIGINT, FK -> regions, Nullable (화면의 지역 정보 렌더링 및 `region_colored` 대응 목적)
  * `quest_progress_id`: BIGINT, FK -> quest_progress, Nullable
  * `event_type`: VARCHAR(30) ('quest_completed', 'region_colored' 등)
  * `title`: VARCHAR(100) (완료한 퀘스트의 타이틀 등, Nullable)
  * `occurred_at`: TIMESTAMP (이벤트 발생 시각)
* **인덱스 구성**: `(user_id, occurred_at DESC)` 복합 인덱스 설정을 통해 대용량 최신순 조회 처리 가속.

## 의사결정 (함께 논의 · 근거 필수)

| 결정할 항목 | 선택지 | 제안 / 근거 | 상태 |
|------|--------|------------|------|
| **타임라인 적재 연동 방식** | A) 이벤트 핸들러(Event-driven) 비동기 처리<br>B) 퀘스트 완료 서비스 레이어 내 인라인 동기 호출 | **B) 인라인 동기 호출 제안**<br>- 프로젝트 규모 상, 복잡한 비동기 이벤트 큐나 브로커를 도입하는 것은 오버엔지니어링입니다.<br>- 퀘스트 완료 비즈니스 트랜잭션과 동일한 세션 내에서 타임라인 레코드를 추가하는 것이 데이터 무결성 및 정합성 보장에 훨씬 유리합니다. | 합의됨 |
| **월별 필터링 처리 방식** | A) 서버 API 레벨에서 `?month=N` 쿼리 파라미터 필터링 지원<br>B) 서버는 전체 목록을 넘겨주고, 프론트엔드가 메모리에서 월별로 필터링/그룹핑 | **A) API 레벨 쿼리 파라미터 필터 지원 제안**<br>- 타임라인 데이터가 수백 개 이상 누적되었을 때, 전체 데이터를 로드하는 것은 네트워크 오버헤드가 큽니다.<br>- 서버가 `?year=YYYY&month=MM` 필터를 지원하되, 기본적으로는 페이징 처리가 가능하도록 설계합니다. | 논의 중 |

## 영향 범위
* `backend/app/main.py`: 타임라인 라우터 추가 등록
* `backend/app/timeline/`: [NEW] 신규 패키지 및 모듈 구성 (models, schemas, repository, service, router)
* `backend/app/quests/service.py` 또는 `verify_quest` 로직: 성공 시 타임라인 레코드 생성 함수 호출 부분 추가
* `backend/alembic/versions/`: [NEW] alembic 마이그레이션 파일 추가

## 작업 단계
- [ ] 1. Alembic 데이터베이스 마이그레이션 생성 및 `timeline` 테이블 모델 정의
- [ ] 2. `TimelineRepository`, `TimelineService` 구축 (타임라인 적재 및 최신순 조회 쿼리)
- [ ] 3. 퀘스트 완료 및 시·군 색칠 트리거 시점에 타임라인 자동 적재 로직 연동
- [ ] 4. 타임라인 조회 엔드포인트 (`GET /api/v1/users/me/timeline`) 라우터 구현
- [ ] 5. 단위 및 통합 테스트 코드 작성 및 검증 (`backend/tests/test_timeline.py`)

## 리스크 / 미해결 질문
* 타임라인 카드에 사용자가 업로드했던 **퀘스트 인증 사진**을 보여줄 것인가?
  * 만약 보여주어야 한다면, 조회 시 `quest_progress` -> `verification_photo` 등의 테이블을 추가 조인하여 사진 파일 주소를 반환해주어야 합니다. (현재 제공된 화면 템플릿 상에는 사진 미리보기가 없으나, 확장 가능하도록 조인 관계 설정 필요)
