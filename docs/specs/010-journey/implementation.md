# [구현 수준] 여정·퀘스트 인증 (Journey & Quest Verification)

| 항목 | 내용 |
|------|------|
| 상태 | 진행 중 (백엔드 구현·테스트 완료 / Notion 역동기화·GCS 버킷 IaC 대기) |
| 최종 업데이트 | 2026-07-05 |

## 구현 규모 / 단위 분할

- **규모 판단**: 단위로 나눠 구현 — 테이블 3개 + API 10개로 규모가 크고, 여정/추천/인증이
  서로 독립적으로 검증 가능하다. 마이그레이션은 005-auth-member(users)에 체인되므로 선행 확인이 필요하다.
- **구현 단위**:
  - [x] 1) 테이블·모델·마이그레이션 — `journeys`·`journey_quests`·`quest_progress` (UUID v7 PK·공통 타임스탬프·Soft Delete). Alembic `f4b2a9c67e18` (005-auth-member `d7b712f1a245`에 체인).
  - [x] 2) 여정 API — POST/GET `/journeys`, GET `/journeys/{id}`, POST/DELETE `/journeys/{id}/quests…` (JRN-01·02). 생성 검증(지역-퀘스트 소속)·진행률·soft delete 복원 포함.
  - [x] 3) 추천 API — GET `/quests/recommended` (REC-01). DNA seam(`app/quests/dna.py`) + `?category=` fallback, 완료 퀘스트 제외·카테고리 일치 우선 정렬.
  - [x] 4) 진행·인증 API — POST `/quests/{id}/start`·`/verify`, GET `/users/me/progress` (VRF-01~04). gps_photo(하버사인 반경)·quiz(정규화 비교) 판정, 완료 시 여정 자동 완료.
  - [x] 5) 사진 업로드 — POST `/uploads/photo` + 스토리지 추상화(`GCS_UPLOAD_BUCKET` 설정 시 GCS, 미설정 시 로컬 디스크) (VRF-03).
  - [~] 6) 검증·문서 — pytest 40건·ruff·pyright 통과, README 갱신 완료. **Notion(테이블·API 명세) 역동기화 남음**.

## 구현된 항목

- **테이블**: `journeys`·`journey_quests`·`quest_progress` — 모델(`app/journeys/models.py`, `app/quests/models.py`) + 마이그레이션(`f4b2a9c67e18`)
- **여정**: 생성(지역 1개+퀘스트 선택)·내 목록(status 필터)·상세(퀘스트별 진행상태·진행률)·퀘스트 추가/제거(복원 포함), 모든 퀘스트 완료 시 자동 완료 (`app/journeys/`)
- **추천**: 완료 퀘스트 제외, 적용 카테고리(파라미터 > DNA seam) 일치 우선 정렬, `is_dna_match`·`applied_category` 노출 (`app/quests/service.py`)
- **진행·인증**: start(멱등)·verify(gps_photo/quiz 룰 판정, 실패 사유 반환)·내 진행 목록, 완료 409 재인증 방지 (`app/quests/verification.py`)
- **업로드**: multipart 사진 업로드(형식·크기 검증) → photo_url, GCS/로컬 스토리지 추상화 (`app/uploads/`)
- **에러코드**: `CONFLICT_ERROR`(409) 추가 (`app/core/exceptions.py`)
- **테스트**: `tests/test_journey_flow.py`·`test_quest_verification.py`·`test_uploads.py` — 전체 40건 통과

## 미구현 / 남은 항목

- **Notion 역동기화**: 테이블 설계(journeys·journey_quests 신설, quest_progress에 journey_id·quiz_answer 추가)·API 명세서(여정 5개 엔드포인트 추가) 반영
- **GCS 버킷 IaC**: 버킷 생성·앱 SA `roles/storage.objectAdmin`·공개 읽기(또는 서빙 방식) — infra/ 후속 작업
- **LLM 사진 판정**: `mission_meta.judgement_prompt` 데이터만 준비됨 (후속)
- **DNA 연동**: `app/quests/dna.py` seam을 DNA 도메인 완성 시 교체

## 알려진 한계 / TODO

- **사진 판정**: MVP는 룰 기반(GPS 반경 + 사진 존재). 사진 내용 검증 없음.
- **퀘스트 조회 공개 여부**: Notion API 명세는 QST 조회(목록·상세·지역)도 인증 Y이나, 000-quest 구현은 공개로 되어 있음. 본 spec 범위(추천·진행·인증·여정·업로드)는 전부 보호 API로 구현 — 조회 API 보호 여부는 000-quest와 함께 팀 결정 필요.
- **재도전(재인증) 정책**: 완료한 퀘스트 재인증은 409. 완료 취소/재도전이 필요해지면 별도 결정.
- **의존**: PR #13(005-auth-member) 머지 전까지 본 브랜치는 그 위에 스택됨.

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-07-05 | 최초 작성 (계획) — Notion API 명세·테이블 설계(초안) 검토 및 여정 테이블 신설 결정 반영 |
| 2026-07-05 | 의사결정 확정(PR #13 스택·GCS 저장·nearby 제외) 및 구현 단위 1~5 완료, 테스트 40건 통과 |
