# [구현 수준] 홈 DNA 지역 추천 + 퀘스트 요약

| 항목 | 내용 |
|------|------|
| 상태 | 폐기 — 홈 배너는 [065-quest-recommendation-api](../065-quest-recommendation-api/)가 담당 |
| 최종 업데이트 | 2026-08-06 |

> **이 스펙의 구현은 FE·BE 모두 제거됐다. 기록 보존용 문서다.**
> KAN-59(065)에서 홈 배너를 `GET /regions/unvisited` + `GET /quests/recommended`로 교체하면서
> 정적 폴백을 없앴고, `GET /api/v1/home/recommendation`을 부르는 클라이언트가 0이 됐다.
> 2026-08-06에 FE 3개 파일과 BE `app/home/`(라우터·서비스·스키마)·`main.py` 등록·
> `tests/test_home_recommendation.py`를 함께 삭제했다.
> 되살릴 필요가 생기면 커밋 히스토리에서 복원한다.

## 구현 규모 / 단위 분할

- **규모 판단**: 한 번에 구현 — 근거: BE 조회 전용 도메인 1개 + FE 배너 확장으로 단위가 작다.

## 구현된 항목

- [x] ~~BE `GET /api/v1/home/recommendation`(지역 선정 + 퀘스트 요약 최대 3개)~~ → 2026-08-06 삭제. 같이 도입했던 `app/quests/dna.py`의 `User.dna` 실조회는 **남아 있고 065가 계속 쓴다**.
- [x] ~~BE 테스트 `tests/test_home_recommendation.py`~~ → 2026-08-06 삭제
- [x] ~~FE 모델·레포지토리·provider + 배너 퀘스트 요약 3개(썸네일 포함)~~ → 2026-08-06 삭제(065가 대체)
- [x] ~~FE API 실패·비로그인 시 정적 폴백 — 위젯 테스트에서 폴백 경로 렌더 확인~~ → 2026-08-06 폴백 제거(065)
- [x] BE 카테고리 값(`activity`)을 FE 어휘(`active`)로 변환하는 매핑 — 매핑 자체(`data/models/category_vocabulary.dart`)는 살아 있고 DNA 설문 경로에서 계속 쓰인다.

## 미구현 / 남은 항목

- [ ] (후속) 추천 다양화(최근 본 지역 제외, 계절 가중치 등) — 이어간다면 065에서 다룬다.

## 알려진 한계 / TODO

아래는 이 스펙이 살아 있던 시점(2026-07/08~2026-08-05)의 한계 기록이다. 065가 대체한 지금은 셋 다 해당하지 않는다.

- ~~FE 정적 퀘스트 id와 BE 퀘스트 UUID가 달라, API 응답 퀘스트는 표시용으로만 쓰고 개별 퀘스트 딥링크는 하지 않는다(지역 이동만).~~ → 부분 해소. 065는 KAN-55의 `DomainCatalog`로 서버 UUID를 정적 `client_key`에 매핑하므로, **지역 개요**의 추천 퀘스트 타일은 `/quest/{id}` 상세로 직접 이동한다(`region_overview_screen.dart:225`). **홈 배너**의 퀘스트 요약은 지금도 표시 전용이고 탭하면 지역으로 이동한다(`home_screen.dart:337`) — 배너는 요약 줄에 개별 탭 타깃을 두지 않는 디자인이라 그대로 뒀다.
- ~~추천 지역 선정에서 "완료 여정 없는 지역 우선"은 서버 기준(journeys)이며, FE 폴백 경로는 로컬 여행 상태 기준이다 — 값이 다를 수 있음(수용).~~ → 무효. 065가 정적 폴백을 없애 FE에 별도 기준이 남아 있지 않다. 지역 선정은 서버(`GET /regions/unvisited`) 단일 기준이다.
- ~~지역에 퀘스트가 하나도 없으면 404를 반환한다(FE는 정적 폴백으로 내려앉음).~~ → 무효. 065의 `GET /regions/unvisited`는 404를 쓰지 않고, 표시할 퀘스트가 있는 지역만(`HAVING available_quest_count > 0`) 내려준다. 목록이 비면 FE는 폴백 대신 배너를 숨긴다.

- BE `activity` ↔ FE `active` 카테고리 어휘 불일치는 여전히 유효하다 — 변환은 `data/models/category_vocabulary.dart`가 담당하며 DNA 설문 경로에서 계속 쓰인다.

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-07-30 | 최초 작성 (KAN-58) |
| 2026-07-31 | 구현 완료. 검증에서 발견한 BE `activity` ↔ FE `active` 카테고리 어휘 불일치 매핑 추가 |
| 2026-08-06 | KAN-59(065)가 홈 배너를 `/regions/unvisited` + `/quests/recommended`로 대체. `/home/recommendation`을 쓰던 FE 3개 파일(`data/models/home_recommendation.dart`, `data/repositories/home_repository.dart`, `state/home_recommendation_provider.dart`) 삭제 |
| 2026-08-06 | 스펙 폐기. 클라이언트가 0이 된 BE `app/home/`(라우터·서비스·스키마)·`main.py` 등록·`tests/test_home_recommendation.py`를 삭제했다. 이 테스트 4건은 dev에서도 실패 중이었고(마이그레이션이 시드한 지역과 픽스처의 `regions.area_code` 중복, 그리고 시드된 퀘스트 때문에 "퀘스트 0개 → 404" 전제가 무효화), 아무도 부르지 않는 API를 위해 시나리오를 재설계하는 대신 제거하는 쪽을 택했다. `app/quests/dna.py`는 065가 계속 쓰므로 유지 |
