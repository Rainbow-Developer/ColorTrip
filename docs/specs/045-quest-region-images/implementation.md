# [구현 수준] 퀘스트·지역 이미지

| 항목 | 내용 |
|------|------|
| 상태 | 완료 |
| 최종 업데이트 | 2026-07-31 |

## 구현 규모 / 단위 분할

- **규모 판단**: 단위로 나눠 구현 — 근거: 데이터 보강(스크립트·외부 API 의존)과 화면 적용(FE)을 분리하면 실패 지점을 격리할 수 있다.
- **구현 단위**:
  - [x] 1) 보강 스크립트 + 정적 데이터 갱신 — 완료 기준 충족: 퀘스트 이미지 210/220, 좌표 211/220, **gps 퀘스트 28개 좌표 100%**, 지역 대표 이미지 11/11
  - [x] 2) FE 모델·위젯·화면 적용 — `flutter analyze` 0건, `flutter test` 통과, placeholder 폴백 동작 확인

## 구현된 항목

- [x] `backend/scripts/enrich_frontend_quests.py` — TourAPI 매칭(areaBasedList2 + searchKeyword2 보강, 장소명 별칭 사전) 후 dart 필드 삽입(재실행 가능)
- [x] `Quest.imageUrl`/`lat`/`lng`/`verifyRadius`, `Region.imageUrl` 필드 추가
- [x] 공용 위젯 `AppNetworkImage`(cached_network_image 래퍼, 로딩·에러·URL 없음 → 기존 placeholder 폴백)
- [x] 화면 적용 — 퀘스트 목록·상세, 지역 개요(헤더·썸네일), 퀘스트 선택
- [x] 테스트 `test/quest_images_test.dart` — placeholder 폴백, 이미지 없는 데이터로 목록 렌더

## 미구현 / 남은 항목

- [ ] 매칭 실패 10건(`dy1`, `cj19`, `be5`, `cu4`, `jc5`, `jp2`, `jp4`, `gs4`, `oc4`, `oc19`)의 이미지 — 대부분 "OO 시내"처럼 TourAPI에 대응 관광지가 없는 장소. placeholder로 노출되며 필요 시 수동 지정.
- [ ] 앱 정보 화면에 이미지 출처(한국관광공사) 고지 — 출시 전 필요

## 알려진 한계 / TODO

- 장소명 매칭 실패 항목은 이미지 없음(placeholder 유지) — 위 목록 참고.
- 이미지 저작권: TourAPI 제공 이미지는 원 출처(한국관광공사) 표기 규약 준수 대상 — 출시 전 앱 정보 화면에 출처 고지 추가 필요(후속).

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-07-30 | 최초 작성 (KAN-58) |
| 2026-07-31 | 구현·데이터 보강 완료. searchKeyword2가 areaCode 파라미터를 주면 0건을 반환하는 문제를 발견해 주소(addr1) 기반 클라이언트 필터로 우회 |
