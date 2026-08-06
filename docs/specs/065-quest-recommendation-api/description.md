# [설명] 퀘스트 추천 API 연동

## 개요

로그인한 사용자의 여행 DNA와 서버에 저장된 여정·퀘스트 완료 상태를 이용해 홈의 추천 여행지와 지역 개요의 추천 퀘스트를 제공한다.

## 동작 방식

1. 홈 추천 카드와 지역 개요는 `GET /quests/recommended?region_id=...&size=3`으로 동일한 DNA 일치 미완료 퀘스트를 받는다.
2. 홈은 `GET /regions/unvisited`로 여정 미생성 지역을 받고 첫 결과를 추천한다.
3. 여정 생성·수정·퀘스트 완료 뒤 KAN-55 도메인 상태 갱신이 추천 Provider를 다시 조회한다.

## 주요 구성 요소 / 위치

| 구성 요소 | 역할 | 위치 |
|---|---|---|
| 추천 조회 | DNA·완료 상태 기반 퀘스트 정렬 | `backend/app/quests/` |
| 미시작 지역 추천 | 여정 이력 제외 및 집계 | `backend/app/regions/` |
| 도메인 저장소 | API 응답을 안정 키로 변환 | `frontend/lib/data/repositories/domain_repository.dart` |
| 추천 화면 | 홈 배너·지역 개요 표시 | `frontend/lib/features/home/`, `frontend/lib/features/quests/` |

## 예시

`GET /api/v1/regions/unvisited`는 `matching_quest_count`가 가장 높은 지역부터 반환한다. 지역 개요는 `GET /api/v1/quests/recommended`로 받은 **추천 퀘스트의 `client_key`** 를 기존 퀘스트 상세 라우트에 전달한다. 지역 라우팅은 `client_key`가 아니라 정적 카탈로그의 지역 키를 쓴다 — `/regions/unvisited` 응답의 `id`(서버 UUID)를 `regionKey`로 변환해 사용한다.

## 관련 문서

- `docs/specs/010-journey/`
- `docs/specs/040-domain-state-persistence/`
