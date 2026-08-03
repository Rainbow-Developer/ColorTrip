# [설명] 홈 DNA 지역 추천 + 퀘스트 요약

## 개요

홈 화면 추천 배너가 사용자의 여행 DNA에 맞는 지역을 추천하면서, 그 지역의 대표 퀘스트 최대 3개(제목·유형·썸네일)를 함께 요약해 보여준다. 추천은 백엔드 API가 계산하고, API를 쓸 수 없으면 프론트 정적 데이터로 동일한 배너를 구성한다.

## 동작 방식

1. 홈 진입 시 FE가 `GET /api/v1/home/recommendation`(Bearer)을 호출한다.
2. BE는 사용자 `User.dna`(미판정 시 nature)를 읽고, 그 카테고리 퀘스트가 가장 많은 지역(완료 여정 없는 지역 우선)을 고른 뒤 대표 퀘스트 3개를 함께 반환한다.
3. FE는 지역명을 로컬 지역 id로 매핑(`regionIdByName`)해 배너를 그린다. 퀘스트 요약은 유형 이모지·제목·썸네일로 표시한다.
4. API 실패(비로그인·서버 미가동) 시 기존 정적 계산(같은 규칙)으로 폴백한다. 배너 탭 시 `/region/{id}` 이동(기존과 동일).

## 주요 구성 요소 / 위치

| 구성 요소 | 역할 | 위치 |
|-----------|------|------|
| 추천 API | 지역 선정 + 퀘스트 요약 조합 | `backend/app/home/router.py`·`service.py`·`schemas.py` |
| DNA 조회 | `User.dna` → 퀘스트 카테고리 | `backend/app/quests/dna.py` |
| 추천 모델/레포지토리 | 응답 파싱·API 호출 | `frontend/lib/data/models/home_recommendation.dart`, `lib/data/repositories/home_repository.dart` |
| 추천 배너 | 지역 + 퀘스트 요약 렌더링·폴백 | `frontend/lib/features/home/home_screen.dart` |

## 설정 / 사용법

- 엔드포인트: `GET /api/v1/home/recommendation` (보호, Envelope 응답)
- FE 폴백: dio 예외 시 정적 데이터 경로로 자동 전환(추가 설정 없음)

## 예시

DNA가 "미식"인 사용자 → "제천시 — 미식 퀘스트 7개가 기다리고 있어요" + 「약채락 맛보기」 등 퀘스트 3개 요약 표시.

## 관련 문서

- [plan.md](plan.md) · [implementation.md](implementation.md)
- 여행 DNA: [docs/specs/010-travel-dna/](../010-travel-dna/)
