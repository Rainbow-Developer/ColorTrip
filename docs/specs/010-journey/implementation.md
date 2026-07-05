# [구현 수준] 여정·퀘스트 인증 (Journey & Quest Verification)

| 항목 | 내용 |
|------|------|
| 상태 | 계획 |
| 최종 업데이트 | 2026-07-05 |

## 구현 규모 / 단위 분할

- **규모 판단**: 단위로 나눠 구현 — 테이블 3개 + API 10개로 규모가 크고, 여정/추천/인증이
  서로 독립적으로 검증 가능하다. 마이그레이션은 005-auth-member(users)에 체인되므로 선행 확인이 필요하다.
- **구현 단위**:
  - [ ] 1) 테이블·모델·마이그레이션 — `journeys`·`journey_quests`·`quest_progress` (UUID v7 PK·공통 타임스탬프·Soft Delete). Alembic revision은 005-auth-member의 users revision에 체인. 완료 기준: 마이그레이션 적용·롤백 동작.
  - [ ] 2) 여정 API — POST/GET `/journeys`, GET `/journeys/{id}`, POST/DELETE `/journeys/{id}/quests…` (JRN-01·02). 완료 기준: 생성 검증(지역-퀘스트 소속)·목록/상세(진행률 포함) 동작.
  - [ ] 3) 추천 API — GET `/quests/recommended` (REC-01, DNA seam + category fallback). 완료 기준: 카테고리 매칭 정렬 확인.
  - [ ] 4) 진행·인증 API — POST `/quests/{id}/start`·`/verify`, GET `/users/me/progress` (VRF-01~04). 완료 기준: gps_photo(반경)·quiz(정답) 판정, 완료 시 여정 자동 완료.
  - [ ] 5) 사진 업로드 — POST `/uploads/photo` + 로컬 스토리지 추상화 (VRF-03). 완료 기준: multipart 업로드 → photo_url 반환·정적 서빙.
  - [ ] 6) 검증·문서 — 테스트(ruff·pyright 포함), README `주요 기능과 위치` 갱신, Notion(테이블·API 명세) 역동기화 목록 정리.

## 구현된 항목

- (없음 — 계획 단계)

## 미구현 / 남은 항목

- 위 구현 단위 1~6 전체

## 알려진 한계 / TODO

- **사진 판정**: MVP는 룰 기반(GPS 반경 + 사진 존재). LLM 판정은 `mission_meta.judgement_prompt` 데이터만 준비하고 후속.
- **DNA 연동**: DNA 도메인 미구현 — `get_user_primary_category` seam이 None이면 `?category=` fallback. DNA 도메인 완성 시 교체.
- **스토리지**: 로컬 디스크(단일 인스턴스 전제). GCS 전환 시 스토리지 구현체만 교체.
- **의존**: PR #13(005-auth-member) 머지 전까지 본 브랜치는 그 위에 스택됨.

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-07-05 | 최초 작성 (계획) — Notion API 명세·테이블 설계(초안) 검토 및 여정 테이블 신설 결정 반영 |
