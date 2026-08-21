# [구현 수준] 관광지 정보 실시간 조회

| 항목 | 내용 |
|------|------|
| 상태 | 계획 |
| 최종 업데이트 | 2026-08-21 |

## 구현 규모 / 단위 분할

- **규모 판단**: 단위로 나눠 구현 — 근거: backend(프록시 모듈·인증 보강)와 frontend(모델·화면 연동)가 API 계약으로 분리되고, 사이에 dart 백필이라는 데이터 준비 단계가 있다. 단위마다 독립적으로 테스트 가능.
- **구현 단위**:
  - [ ] 1) backend places 프록시 — `TourApiClient.fetch_detail_common` 추가, `app/places/` 모듈·엔드포인트 2개, 실패 시 null 필드 응답. 완료 기준: 백엔드 테스트 통과(키 없음·TourAPI 오류·정상 응답 케이스)
  - [ ] 2) backend 인증 프롬프트 보강 — content_id 있는 퀘스트의 사진 판정 프롬프트에 소개문 포함, 실패 시 기존 프롬프트. 완료 기준: 판정 테스트 통과
  - [ ] 3) dart 백필 — `tourContentId`·`tourContentTypeId` 삽입, TourAPI 유래 `imageUrl`·`desc` 제거(수제 desc·로컬 asset 불변). 완료 기준: 스크립트 재실행 가능 + flutter analyze 통과
  - [ ] 4) frontend 연동 — Quest 모델·PlaceRepository·지역/상세 화면 로딩·placeholder. 완료 기준: 프론트 테스트 통과 + 앱 실행 확인
  - [ ] 5) 문서 동기화 — external-apis 호출 지점 절·README·045 상태·specs 인덱스

## 구현된 항목

- [ ] (없음)

## 미구현 / 남은 항목

- [ ] 위 구현 단위 1)~5) 전부

## 알려진 한계 / TODO

* 개발계정 일 1,000건 한도 — 사용자 증가 시 운영계정 전환 필요(초과 시 placeholder로 동작 유지).
* 캐시 없음(권고 준수) — 같은 화면 재진입도 매번 호출한다.
* `backend/app/integrations/tour_api/loader.py`는 여전히 미연결 — 제거·활용 여부는 별도 결정.
* 행사·축제(searchFestival2)·연관 관광지(TarRlteTarService1)는 다음 태스크.

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-08-21 | 최초 작성 |
