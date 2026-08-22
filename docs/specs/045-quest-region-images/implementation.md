# [구현 수준] 퀘스트·지역 이미지

| 항목 | 내용 |
|------|------|
| 상태 | 완료 (퀘스트 이미지 정적 보강은 [090](../090-realtime-tour-place-info/)이 대체 — 지역 대표 로컬 asset·좌표 보강은 유효) |
| 최종 업데이트 | 2026-08-21 |

## 구현 규모 / 단위 분할

- **규모 판단**: 단위로 나눠 구현 — 근거: 데이터 보강(스크립트·외부 API 의존)과 화면 적용(FE)을 분리하면 실패 지점을 격리할 수 있다.
- **구현 단위**:
  - [x] 1) 보강 스크립트 + 정적 데이터 갱신 — 완료 기준 충족: 퀘스트 이미지 210/220, 좌표 211/220, **gps 퀘스트 28개 좌표 100%**, 지역 대표 이미지 11/11
  - [x] 2) FE 모델·위젯·화면 적용 — `flutter analyze` 0건, `flutter test` 통과, placeholder 폴백 동작 확인

## 구현된 항목

- [x] `backend/scripts/enrich_frontend_quests.py` — TourAPI 매칭(areaBasedList2 + searchKeyword2 보강, 장소명 별칭 사전) 후 dart 필드 삽입(재실행 가능)
- [x] `Quest.imageUrl`/`lat`/`lng`/`verifyRadius`, `Region.imageUrl` 필드 추가
- [x] 공용 위젯 `AppNetworkImage`(cached_network_image 래퍼, `asset:` 로컬 이미지 지원, 로딩·에러·URL 없음 → 기존 placeholder 폴백)
- [x] 화면 적용 — 퀘스트 목록·상세, 지역 개요(헤더·썸네일), 퀘스트 선택
- [x] KAN-100 청주시 지역 개요 대표 이미지 — `frontend/assets/images/region_cheongju_main.png` 로컬 asset 적용
- [x] KAN-100 충주시 지역 개요 대표 이미지 — `frontend/assets/images/region_chungju_main.png` 로컬 asset 적용
- [x] KAN-100 단양군 지역 개요 대표 이미지 — `frontend/assets/images/region_danyang_main.png` 로컬 asset 적용
- [x] KAN-100 음성군 지역 개요 대표 이미지 — `frontend/assets/images/region_eumseong_main.png` 로컬 asset 적용
- [x] KAN-100 괴산군 지역 개요 대표 이미지 — `frontend/assets/images/region_goesan_main.png` 로컬 asset 적용
- [x] KAN-100 증평군 지역 개요 대표 이미지 — `frontend/assets/images/region_jeungpyeong_main.png` 로컬 asset 적용
- [x] KAN-100 진천군 지역 개요 대표 이미지 — `frontend/assets/images/region_jincheon_main.png` 로컬 asset 적용
- [x] KAN-100 옥천군 지역 개요 대표 이미지 — `frontend/assets/images/region_okcheon_main.png` 로컬 asset 적용
- [x] KAN-100 보은군 지역 개요 대표 이미지 — `frontend/assets/images/region_boeun_main.png` 로컬 asset 적용
- [x] KAN-100 제천시 지역 개요 대표 이미지 — `frontend/assets/images/region_jecheon_main.png` 로컬 asset 적용
- [x] KAN-100 영동군 지역 개요 대표 이미지 — `frontend/assets/images/region_yeongdong_main.png` 로컬 asset 적용
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
| 2026-08-19 | KAN-100: 청주시 지역 개요 대표 이미지를 제작 asset(`region_cheongju_main.png`)으로 교체 |
| 2026-08-19 | KAN-100: 충주시 지역 개요 대표 이미지를 제작 asset(`region_chungju_main.png`)으로 교체 |
| 2026-08-19 | KAN-100: 단양군 지역 개요 대표 이미지를 제작 asset(`region_danyang_main.png`)으로 교체하고, `AppNetworkImage`가 `asset:` 스킴을 렌더링하도록 확장 |
| 2026-08-19 | KAN-100: 음성군 지역 개요 대표 이미지를 제작 asset(`region_eumseong_main.png`)으로 교체 |
| 2026-08-19 | KAN-100: 괴산군 지역 개요 대표 이미지를 제작 asset(`region_goesan_main.png`)으로 교체 |
| 2026-08-19 | KAN-100: 증평군 지역 개요 대표 이미지를 제작 asset(`region_jeungpyeong_main.png`)으로 교체 |
| 2026-08-19 | KAN-100: 진천군 지역 개요 대표 이미지를 제작 asset(`region_jincheon_main.png`)으로 교체 |
| 2026-08-19 | KAN-100: 옥천군 지역 개요 대표 이미지를 제작 asset(`region_okcheon_main.png`)으로 교체 |
| 2026-08-19 | KAN-100: 보은군 지역 개요 대표 이미지를 제작 asset(`region_boeun_main.png`)으로 교체 |
| 2026-08-19 | KAN-100: 제천시 지역 개요 대표 이미지를 제작 asset(`region_jecheon_main.png`)으로 교체 |
| 2026-08-19 | KAN-100: 영동군 지역 개요 대표 이미지를 제작 asset(`region_yeongdong_main.png`)으로 교체 |
| 2026-08-21 | 퀘스트 썸네일·소개문의 정적 저장 방식이 [090-realtime-tour-place-info](../090-realtime-tour-place-info/)의 실시간 조회로 대체됨(`imageUrl`·생성 desc 제거, `tourContentId` 백필). 지역 대표 로컬 asset과 좌표(lat/lng)·`AppNetworkImage`는 계속 유효 |
| 2026-08-21 | `AppNetworkImage` placeholder를 회색 단색 박스에서 연한 그라데이션 배경으로 교체(KAN-103 피드백). `placeholderEmoji` 경로는 기존 동작 유지, `placeholderText` 경로는 풍경 아이콘 + 텍스트 세로 배치로 변경, 둘 다 없으면 풍경 아이콘만 표시 |
