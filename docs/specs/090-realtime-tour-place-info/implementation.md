# [구현 수준] 관광지 정보 실시간 조회

| 항목 | 내용 |
|------|------|
| 상태 | 진행 중 |
| 최종 업데이트 | 2026-08-21 |

## 구현 규모 / 단위 분할

- **규모 판단**: 단위로 나눠 구현 — 근거: backend(프록시 모듈·인증 보강)와 frontend(모델·화면 연동)가 API 계약으로 분리되고, 사이에 dart 백필이라는 데이터 준비 단계가 있다. 단위마다 독립적으로 테스트 가능.
- **구현 단위**:
  - [x] 1) backend places 프록시 — `TourApiClient.fetch_detail_common` 추가, `app/places/` 모듈·엔드포인트 2개, 실패 시 null 필드 응답. 완료 기준: 백엔드 테스트 통과(키 없음·TourAPI 오류·정상 응답 케이스)
  - [x] 2) backend 인증 프롬프트 보강 — content_id 있는 퀘스트의 사진 판정 프롬프트에 소개문 포함, 실패 시 기존 프롬프트. 완료 기준: 판정 테스트 통과
  - [x] 3) dart 백필 — `tourContentId`·`tourContentTypeId` 삽입(211/220, 미매칭 9건은 '시내' 등 자유 퀘스트), TourAPI 유래 `imageUrl`·생성 `desc` 제거. 서버 quests.content_id도 같은 스냅숏으로 백필(alembic a1c2e3d4f5a6)
  - [x] 4) frontend 연동 — Quest 모델·PlaceRepository·QuestImage 위젯(썸네일 7개 사용처)·상세 소개문/운영정보. flutter analyze 0건, 테스트 187 passed
  - [x] 5) 문서 동기화 — external-apis 호출 지점 절·README·045 상태·specs 인덱스

## 구현된 항목

- [x] 구현 단위 1)~5) 전부 (backend 테스트 266건·frontend 테스트 187건 통과)

## 미구현 / 남은 항목

- [ ] dev 서버 배포 후 실기기 검증(Secret Manager `colortrip-dev-tour-api-key`는 생성·값 일치 확인됨 — 2026-08-21)

## 알려진 한계 / TODO

* 백필이 `searchKeyword2` 폴백으로 매칭한 유형 38(쇼핑) 3건·15(행사) 1건은 지역 썸네일 맵(`areaBasedList2` 12·14·28·39)에 없어 **목록 썸네일이 placeholder**로 남고, 운영정보 필드 정규화(`_OPERATION_FIELDS`)에도 없어 운영정보가 null이다. 상세 화면 이미지는 `detailCommon2`의 대표 이미지를 쓰므로 표시된다.

* 개발계정 일 1,000건 한도 — 사용자 증가 시 운영계정 전환 필요(초과 시 placeholder로 동작 유지).
* 캐시 없음(권고 준수) — 같은 화면 재진입도 매번 호출한다.
* `backend/app/integrations/tour_api/loader.py`는 여전히 미연결 — 제거·활용 여부는 별도 결정.
* 행사·축제(searchFestival2)·연관 관광지(TarRlteTarService1)는 다음 태스크.

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-08-21 | 최초 작성 |
| 2026-08-21 | 구현 단위 1)~5) 완료 — places 프록시·인증 프롬프트 보강·contentId 백필(dart+DB)·FE 실시간 연동·문서 동기화 |
