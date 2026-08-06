# [계획] 홈 DNA 지역 추천 + 퀘스트 요약

> ⚠️ **폐기된 스펙 — 아래는 2026-07-30 당시 계획 기록이다.**
> 현재 홈 추천은 [065-quest-recommendation-api](../065-quest-recommendation-api/)가 담당하며,
> 여기 계획한 `app/home/` 도메인은 2026-08-06에 제거됐다.
> 현재 상태는 [implementation.md](implementation.md) 참고.

| 항목 | 내용 |
|------|------|
| 기능명 | 홈 DNA 지역 추천 + 퀘스트 요약 |
| Spec 폴더 | `docs/specs/040-home-region-recommendation/` |
| 영역 | 공통 (backend + frontend) |
| 작성자 | Claude Code (KAN-58) |
| 작성일 | 2026-07-30 |
| 상태 | 계획 |

## 배경 / 목적

홈의 추천 배너(KAN-28)는 현재 프론트 위젯 내부에서 정적 데이터로 "DNA와 같은 유형 퀘스트가 가장 많은 미시작 지역"만 계산해 지역명·개수 문구를 보여준다. 사용자가 "무슨 퀘스트가 있는지"를 배너에서 바로 볼 수 있도록 **해당 지역의 대표 퀘스트 몇 개를 요약해 함께 노출**하고, 추천 산출을 백엔드 API로 승격한다(FE는 API 우선, 실패 시 기존 정적 계산 폴백).

## 목표 (Goals)

- 백엔드에 DNA 기반 지역 추천 API(`GET /api/v1/home/recommendation`)를 신설한다.
- 추천 응답에 지역 정보 + 대표 퀘스트 요약(최대 3개: 제목·유형·썸네일)을 포함한다.
- 홈 배너가 퀘스트 요약을 표시한다. API 실패/비로그인 시에도 배너는 정적 데이터로 동작한다.
- `app/quests/dna.py`의 `get_user_primary_category` 스텁을 실제 `User.dna` 조회로 교체한다.

## 비목표 (Non-Goals)

- 추천 알고리즘 고도화(협업 필터링 등) — 규칙 기반(카테고리 매칭 수) 유지.
- 홈 화면 전체 리디자인(KAN-50은 별도 작업).

## 요구사항

- 추천 지역 선정: 사용자 DNA 카테고리의 퀘스트가 가장 많은 지역 중, 완료 여정이 없는 지역 우선. 동률이면 전체 퀘스트 수가 많은 지역.
- DNA 미판정 사용자는 기본 카테고리(nature)로 추천.
- 퀘스트 요약은 DNA 일치 퀘스트 우선, 썸네일 있는 항목 우선.

## 설계 개요 / 접근 방식

- **backend**: 신규 `app/home/` 도메인(`router.py`/`service.py`/`schemas.py`). 보호 엔드포인트 `GET /api/v1/home/recommendation`:

  응답은 공통 Envelope([api-design](../../conventions/api-design.md))로 감싼다 — `data` 아래에 지역·DNA·퀘스트 요약이 온다.

  ```json
  { "code": "SUCCESS", "status": 200, "message": "요청이 성공했습니다.",
    "data": {
      "region": {"id": "...", "name": "청주시", "image_url": null},
      "dna_category": "nature",
      "quests": [{"id": "...", "title": "...", "category": "nature",
                   "mission_type": "gps_photo", "thumbnail_url": "..."}]
    } }
  ```

  집계는 quests 테이블(region_id × category COUNT)과 journeys(완료 여정 존재 여부)로 계산. `region.image_url`은 해당 지역 썸네일 보유 퀘스트에서 대표 1건을 골라 채운다.
- **frontend**: `HomeRecommendation` 모델 + `HomeRepository`(dio, API) 신설. `_RecommendedRegionBanner`를 `FutureProvider` 기반으로 확장 — API 성공 시 응답의 지역·퀘스트 요약 표시, 실패 시 기존 정적 계산으로 동일 UI 구성(퀘스트 요약도 정적 데이터에서 뽑음). 배너 탭 → 기존처럼 `/region/{id}`.
- 지역 매칭: BE `region.name` ↔ FE `regionIdByName`(map_sync과 동일 방식).

## 의사결정 (함께 논의 · 근거 필수)

| 결정할 항목 | 선택지 | 제안 / 근거 | 상태 |
|------|--------|------------|------|
| API 위치 | 신규 home 도메인 / regions 확장 / quests 확장 | **신규 `app/home/`**. 홈 전용 조합(지역+퀘스트+DNA)이라 특정 도메인에 넣으면 결합이 애매해짐. 도메인 5분할 컨벤션 그대로 따름(모델 없는 조회 도메인이라 router/service/schemas만) | 합의됨(구현 승인) |
| FE 데이터 소스 | API 전용 / 정적 전용 / API+정적 폴백 | **API+정적 폴백**. FE는 아직 정적 우선 아키텍처(000-frontend-app)라 서버 미가동·비로그인에서도 홈이 깨지면 안 됨 | 합의됨(구현 승인) |
| 요약 개수 | 2 / 3 / 5 | **3개**. 배너 높이를 크게 늘리지 않으면서 "어떤 퀘스트가 있는지" 감을 주는 최소 수 | 합의됨(구현 승인) |

## 영향 범위

- backend: `app/home/`(신규), `app/main.py`(라우터 등록), `app/quests/dna.py`(스텁 교체), `tests/test_home_recommendation.py`(신규)
- frontend: `lib/features/home/home_screen.dart`, `lib/data/models/home_recommendation.dart`(신규), `lib/data/repositories/home_repository.dart`(신규), `lib/state/repository_providers.dart`
- 문서: README `주요 기능과 위치` 표에 홈 추천 행 추가

## 작업 단계

- [ ] BE: home 도메인 + dna 스텁 교체 + 테스트
- [ ] FE: 모델/레포지토리 + 배너 확장(요약 3개) + 위젯 테스트

## 리스크 / 미해결 질문

- FE 정적 퀘스트 id와 BE 퀘스트 id(UUID)는 다른 체계 — 배너의 퀘스트 요약은 표시용이며, 탭 이동은 지역 단위로만 한다(퀘스트 개별 딥링크는 정적 id일 때만).
