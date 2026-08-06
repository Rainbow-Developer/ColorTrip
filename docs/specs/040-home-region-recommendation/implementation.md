# [구현 수준] 홈 DNA 지역 추천 + 퀘스트 요약

| 항목 | 내용 |
|------|------|
| 상태 | 대체됨 — 홈 배너는 [065-quest-recommendation-api](../065-quest-recommendation-api/)가 담당 |
| 최종 업데이트 | 2026-08-06 |

> **이 스펙의 FE 경로는 더 이상 동작하지 않는다.** KAN-59(065)에서 홈 배너를
> `GET /regions/unvisited` + `GET /quests/recommended`로 교체하면서 정적 폴백을 없앴고,
> `GET /home/recommendation`을 쓰던 FE 코드(모델·레포지토리·provider)는 삭제했다.
> BE 엔드포인트 `GET /api/v1/home/recommendation`과 `tests/test_home_recommendation.py`는
> 아직 남아 있다 — 존치/제거는 아래 "미구현 / 남은 항목" 참고.

## 구현 규모 / 단위 분할

- **규모 판단**: 한 번에 구현 — 근거: BE 조회 전용 도메인 1개 + FE 배너 확장으로 단위가 작다.

## 구현된 항목

- [x] BE `GET /api/v1/home/recommendation`(지역 선정 + 퀘스트 요약 최대 3개) + `app/quests/dna.py` 스텁을 `User.dna` 실조회로 교체
- [x] BE 테스트 `tests/test_home_recommendation.py` — DNA 있음/없음, 완료 여정 지역 후순위, 요약 3개 제한, 퀘스트 0개(404), 미인증(401)
- [x] ~~FE 모델·레포지토리·provider + 배너 퀘스트 요약 3개(썸네일 포함)~~ → 2026-08-06 삭제(065가 대체)
- [x] ~~FE API 실패·비로그인 시 정적 폴백 — 위젯 테스트에서 폴백 경로 렌더 확인~~ → 2026-08-06 폴백 제거(065)
- [x] BE 카테고리 값(`activity`)을 FE 어휘(`active`)로 변환하는 매핑 — 없으면 배너가 DNA를 자연탐험으로 잘못 표시. 매핑 자체(`data/models/category_vocabulary.dart`)는 DNA 설문 경로에서 계속 쓰인다.

## 미구현 / 남은 항목

- [ ] (후속) 추천 다양화(최근 본 지역 제외, 계절 가중치 등)
- [ ] **BE `GET /home/recommendation` 존치 여부 팀 결정** — 호출하는 클라이언트가 없다. 유지한다면 `tests/test_home_recommendation.py`의 현재 실패(픽스처가 마이그레이션 시드 지역과 `regions.area_code` 유니크 충돌)를 고쳐야 하고, 제거한다면 라우터·서비스·스키마·테스트를 함께 지운다. 이 실패는 065 작업 이전부터 dev에 있었다.

## 알려진 한계 / TODO

- FE 정적 퀘스트 id와 BE 퀘스트 UUID가 달라, API 응답 퀘스트는 표시용으로만 쓰고 개별 퀘스트 딥링크는 하지 않는다(지역 이동만).
- 추천 지역 선정에서 "완료 여정 없는 지역 우선"은 서버 기준(journeys)이며, FE 폴백 경로는 로컬 여행 상태 기준이다 — 값이 다를 수 있음(수용).
- 지역에 퀘스트가 하나도 없으면 404를 반환한다(FE는 정적 폴백으로 내려앉음).

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-07-30 | 최초 작성 (KAN-58) |
| 2026-07-31 | 구현 완료. 검증에서 발견한 BE `activity` ↔ FE `active` 카테고리 어휘 불일치 매핑 추가 |
| 2026-08-06 | KAN-59(065)가 홈 배너를 `/regions/unvisited` + `/quests/recommended`로 대체. `/home/recommendation`을 쓰던 FE 3개 파일(`data/models/home_recommendation.dart`, `data/repositories/home_repository.dart`, `state/home_recommendation_provider.dart`)을 삭제하고 이 스펙 상태를 "대체됨"으로 변경. BE 엔드포인트는 존치 여부 미결로 남김 |
