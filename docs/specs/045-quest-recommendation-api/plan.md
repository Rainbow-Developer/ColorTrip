# [계획] 퀘스트 추천 API 연동

| 항목 | 내용 |
|------|------|
| 기능명 | 퀘스트 추천 API 연동 |
| Spec 폴더 | `docs/specs/045-quest-recommendation-api/` |
| 영역 | backend / frontend |
| 작성일 | 2026-07-31 |
| 상태 | 진행 중 |

## 배경 / 목적

KAN-55는 인증, 여정, 완료 기록을 서버 단일 상태로 복원하지만 홈과 지역 개요의 추천은 정적 데이터로 계산한다. 사용자 DNA와 실제 여정·완료 상태를 기준으로 같은 룰을 서버에서 적용한다.

## 목표 (Goals)

- 사용자 DNA 우선 추천 퀘스트를 지역별로 반환한다.
- 여정을 만든 적 없는 지역 중 최적 지역을 홈에 추천한다.
- 홈과 지역 개요가 서버 추천 결과를 표시하고, 여정·완료 변경 뒤 갱신한다.

## 비목표 (Non-Goals)

- 새 로그인, 여정 생성, 퀘스트 인증, 추천 알고리즘 고도화(거리·AI·일정)는 포함하지 않는다.

## 요구사항

- `GET /quests/recommended`는 `category`가 없으면 `users.dna`를 적용하고 완료 퀘스트를 제외한다.
- `GET /regions/unvisited`는 인증 사용자에게 여정 생성 이력이 없는 지역을 반환한다.
- 후보 집계는 완료됐거나 `client_key`가 없는 퀘스트를 제외하고, DNA 일치 수·전체 수·지역명 순으로 정렬한다.
- Flutter는 서버 `slug`·`client_key`를 기존 화면 모델과 라우트에 연결한다.

## 설계 개요 / 접근 방식

백엔드는 `users.dna`와 `quest_progress`·`journeys`를 조회해 추천 결과를 만들고, Flutter의 `DioDomainRepository`가 KAN-55의 도메인 카탈로그로 UUID를 안정 키로 변환한다. 추천 Provider는 도메인 스냅샷을 의존하므로 여정 생성·수정·완료 뒤 자동으로 다시 계산된다.

## 의사결정

| 결정할 항목 | 선택지 | 제안 / 근거 | 상태 |
|---|---|---|---|
| 미시작 지역 기준 | 지도 미방문 / 여정 미생성 | 여정 미생성. 현재 홈의 여행 시작 상태와 KAN-55 서버 여정 상태에 일치한다. | 합의됨 |
| 추천 방식 | 룰 기반 / 거리·AI 모델 | DNA 일치·미완료 룰 기반. 현재 데이터와 MVP 규모에 충분하다. | 합의됨 |

## 영향 범위

- `backend/app/quests/`, `backend/app/regions/` — DNA 조회·추천 API·스키마·조회.
- `frontend/lib/data/repositories/`, `frontend/lib/state/`, `frontend/lib/features/` — 추천 모델·Provider·홈·지역 개요.
- `backend/tests/`, `frontend/test/` — API와 화면 테스트.

## 작업 단계

- [ ] 추천 API 계약·조회·테스트
- [ ] Flutter 도메인 저장소·Provider·화면 연동 테스트
- [ ] 문서 갱신 및 전체 검증

## 리스크 / 미해결 질문

- 서버 카탈로그에 없는 안정 키는 추천 결과에서 제외한다.
