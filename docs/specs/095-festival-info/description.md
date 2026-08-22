# [설명] 지역 행사·축제 정보

## 개요

지역(시·군) 화면의 DNA 카드 아래에서 그 지역의 행사·축제(진행 중이거나 60일 이내 개막 예정)를 가로 스크롤 카드로 보여준다. 카드에는 포스터 이미지·행사명·기간·상태 배지(진행 중 / D-n)가 담기고, 카드를 누르면 행사 상세 바텀시트(포스터·기간·장소·소개·가까운 추천 퀘스트 3개)가 뜬다. 행사가 없거나 조회에 실패하면 섹션 자체가 보이지 않는다.

## 동작 방식

1. 지역 개요 화면 진입 시 `regionFestivalsProvider(regionId)`가 `FestivalRepository.byRegion`을 호출한다.
2. 저장소는 오늘 기준 진행 중(시작일 ≤ 오늘 ≤ 종료일)이거나 60일 이내 개막 예정인 행사만 반환한다.
3. `FestivalSection`이 결과를 가로 스크롤 카드로 렌더링한다. 로딩 중·실패·빈 결과는 섹션을 그리지 않는다.
4. 카드를 누르면 `FestivalDetailSheet` 바텀시트가 뜨고, 행사 좌표 기준 가까운 퀘스트 3개를 거리와 함께 보여준다. 퀘스트를 누르면 퀘스트 상세(`/quest/:id`)로 이동한다.
4. 현재 구현은 `StubFestivalRepository`(지역별 실존 축제 샘플)다. 백엔드 `searchFestival2` 프록시가 생기면 Dio 구현체로 provider override만 교체한다([plan.md](plan.md) 작업 단계 2단계).

## 주요 구성 요소 / 위치

| 구성 요소 | 역할 | 위치 |
|-----------|------|------|
| Festival 모델 | id·행사명·장소명·기간·포스터 URL | `frontend/lib/data/models/festival.dart` |
| FestivalRepository | 지역별 진행 중 행사 조회 인터페이스(+스텁 구현) | `frontend/lib/data/repositories/festival_repository.dart` |
| regionFestivalsProvider | 지역별 행사 상태(autoDispose family) | `frontend/lib/state/repository_providers.dart` |
| FestivalSection | 가로 스크롤 카드 섹션 | `frontend/lib/features/quests/region_overview_screen.dart` |
| FestivalDetailSheet | 행사 상세 바텀시트(+가까운 퀘스트) | `frontend/lib/features/quests/festival_detail_sheet.dart` |

## 설정 / 사용법

* 별도 설정 없음. 백엔드 전환 후에는 TourAPI 키 규약([external-apis](../../conventions/external-apis.md))을 따른다.

## 예시

단양군 화면 → "진행 중 행사·축제" 섹션에 "단양 온달문화축제" 카드(포스터, 10.10~10.13, D-3 배지)가 가로 스크롤로 표시된다.

## 관련 문서

* [external-apis 컨벤션](../../conventions/external-apis.md) — 행사·축제 데이터 소스 결정(SOT)
* [090-realtime-tour-place-info](../090-realtime-tour-place-info/) — 같은 실시간 조회 패턴
