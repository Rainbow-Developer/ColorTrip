<!--
이 파일은 기능 스펙용 공통 템플릿입니다.
새 기능을 시작할 때 docs/specs/{NNN}-{feature-name}/implementation.md 로 복사해 작성하세요.
현재 구현이 어디까지 됐는지를 명시하는 문서입니다. 읽는 사람이 "지금 유효한 내용인지"
판단할 수 있어야 하므로, 구현이 진행될 때마다 상태와 변경 이력을 갱신하세요.
먼저 구현 규모(한 번에 / 분할)를 판단하고, 분할이 필요하면 구현 계획을 단위로 나눠 적습니다.
{ } 안의 placeholder는 실제 값으로 바꾸고, 작성 후 이 안내 주석 블록은 지웁니다.
-->

# [구현 수준] 퀘스트 (Quest)

| 항목 | 내용 |
|------|------|
| 상태 | 진행 중 (조회 API·기반 완료 / TourAPI 실적재는 키 대기) |
| 최종 업데이트 | 2026-06-25 |

## 구현 규모 / 단위 분할

- **규모 판단**: 단위로 나눠 구현 — 첫 백엔드 도메인이라 기반 구조부터 세워야 하고, 데이터 적재(OpenAPI)와 조회 API가 분리되며, 각 단위가 독립적으로 검증 가능하다.
- **구현 단위**:
  - [x] 1) 테이블·모델·마이그레이션 — `regions`·`quests` (UUID v7 PK, 공통 타임스탬프, Soft Delete, 카테고리 enum, mission_meta JSONB). Alembic 마이그레이션 적용.
  - [x] 2) `regions` 마스터 시드(충북 11개 시·군) + `GET /api/v1/regions`.
  - [~] 3) TourAPI 클라이언트 + `quests` 배치 적재 — **골격 완료**, 실적재는 API 키 발급 대기(키 없으면 빈 결과).
  - [x] 4) `GET /api/v1/quests` 목록(지역·카테고리 필터, page/size).
  - [x] 5) `GET /api/v1/quests/{quest_id}` 상세 — DB 데이터 반환. 운영정보(`operation_info`)는 미연결(아래 TODO).

## 구현된 항목

- **backend 기반**: FastAPI 앱(`app/main.py`), 설정(`core/config.py`, pydantic-settings), 비동기 DB 세션(`core/database.py`), 공통 Envelope(`core/response.py`), 에러코드·핸들러(`core/exceptions.py`), 공통 Base/믹스인(`core/base.py` — UUID v7·타임스탬프·Soft Delete)
- **모델·마이그레이션**: `regions`·`quests` (`app/regions/models.py`, `app/quests/models.py`), Alembic `init regions and quests`
- **regions**: 충북 11개 시·군 시드(`app/regions/seed.py`), `GET /api/v1/regions`
- **quests**: `GET /api/v1/quests`(region_id·category 필터, offset page/size), `GET /api/v1/quests/{id}`
- **TourAPI 연동 골격**: `app/integrations/tour_api/client.py`(areaBasedList2·detailIntro2·categoryCode2), `loader.py`(지역별 적재 — 키/area_code 대기)
- **로컬 환경**: `docker-compose.yml`(PostgreSQL + FastAPI), `Dockerfile`, Alembic 설정
- **검증**: ruff 통과, `regions`(11건)·`quests`(목록/상세/404/422) API 동작 확인

## 미구현 / 남은 항목

- TourAPI **실적재**: 키 발급 후 `loader.py`로 `quests` 적재 + 충북 11개 시·군 `area_code`(sigunguCode) 매핑
- 상세 **운영정보**: `quests` 상세에서 `content_id`로 TourAPI 소개정보(시간·휴무·입장료) 조회 → `operation_info` 채우기 (의사결정 5)
- **카테고리 분류코드 매핑**: TourAPI cat1/2/3 → Category 5종 (`loader.py` TODO)
- **인증 적용**: 공통 토큰 미들웨어(CMN-06) 확정 후 보호 API 여부 반영

## 알려진 한계 / TODO

- 공통 기반(CMN-01·02 Envelope/에러핸들러)은 퀘스트 도메인 안에서 최소 구현했다. 별도 공통 기반 작업과 통합 시 중복 정리 필요.
- 시간 컬럼은 `TIMESTAMP WITH TIME ZONE` + KST(`now_kst`)로 저장. database.md의 "KST 저장" 해석은 추후 팀 합의로 확정 가능.
- TourAPI 키가 없을 때 클라이언트는 빈 결과를 반환한다(빠른 실패 대신 빈 적재). 키 발급 후 동작 재검증 필요.

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-06-25 | 최초 작성 (계획) |
| 2026-06-25 | 의사결정 7건 합의 반영 |
| 2026-06-25 | backend 기반·모델·마이그레이션·regions 시드·regions/quests 조회 API·TourAPI 골격 구현 (단위 1·2·4·5 완료, 3 골격) |
