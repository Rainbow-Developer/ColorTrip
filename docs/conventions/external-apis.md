# [컨벤션] 외부 API & 데이터 연동

> **범위**: 관광/지도/행사 데이터 소스·사진 인증·추천·API 키 관리
> **변경 시**: 이 문서를 단일 출처로 갱신합니다 ([AGENT_GUIDE 문서 동기화](../AGENT_GUIDE.md#문서-동기화-필수) 참고).

## 결정 사항

| 항목 | 결정 | 비고 |
|------|------|------|
| 관광 데이터 소스 | 한국관광공사 TourAPI | |
| 지도 / 지역 데이터 | 프론트엔드는 그림(이미지) 방식, 백엔드는 Naver API | |
| 행사·축제 데이터 | TourAPI 행사정보 | |
| 사진 인증 검증 | **Gemini 비전 판정**(제공자 교체 가능 인터페이스, 키 없으면 스텁 판정) | KAN-58에서 룰 기반 → AI 판정으로 변경. [050 스펙](../specs/050-quest-verification/) |
| 퀘스트·지역 이미지 | TourAPI `firstimage` CDN URL 핫링크 | [045 스펙](../specs/045-quest-region-images/) |
| 여행 DNA 추천 | 룰 기반으로 시작 | |
| API 키 / 쿼터 관리 | 환경변수 + GCP Secret Manager | |

## 규칙 / 적용

- 관광·행사 데이터는 TourAPI를 사용한다.
- 백엔드 지도/지역 데이터는 Naver API를 사용한다.
- 사진 인증은 Gemini 비전 판정을 쓰되 `app/integrations/vision/`의 인터페이스 뒤에 두고, 키 미설정 시 스텁으로 동작한다. DNA 추천은 룰 기반 유지.
- API 키는 환경변수 + GCP Secret Manager로 관리한다.

## Gemini (사진 AI 인증)

- **용도**: 퀘스트 인증 사진이 조건에 맞는지 판정 (`backend/app/integrations/vision/`, `POST /api/v1/verifications/photo`).
- **키**: [Google AI Studio](https://aistudio.google.com/apikey)에서 발급 → 로컬 `backend/.env`의 `GEMINI_API_KEY`, 운영은 Secret Manager(생성 시 [deploy/deploy.sh](../../deploy/deploy.sh)에 반영 필요). 모델은 `GEMINI_MODEL`(기본 `gemini-2.5-flash`).
- **미설정 시**: 스텁 판정(항상 통과 + "AI 미설정" 사유) — 데모·테스트는 키 없이 동작한다.
- **쿼터**: 무료 티어는 분당 요청 제한이 있어 초과 시 오류를 그대로 반환한다(폴백 통과 처리하지 않음).

## TourAPI 활용신청 현황 (공공데이터포털, 2026-07-17 승인 · 2028-07-17 만료)

하나의 data.go.kr 계정 인증키로 아래 서비스가 모두 승인되어 있다.
키는 로컬 `backend/.env`의 `TOUR_API_KEY`로 주입하고, 운영은 Secret Manager
`colortrip-dev-tour-api-key`로 관리한다(현재 시크릿 미생성 — 생성 시 dev 서버 배포에 자동 반영,
[deploy/deploy.sh](../../deploy/deploy.sh) 참고).

| 서비스(활용신청 명) | Base URL (`apis.data.go.kr/B551011/…`) | 상태 |
|------|------|------|
| 국문 관광정보 서비스_GW | `KorService2` | **사용 중** — 프론트 퀘스트 데이터 생성 `backend/scripts/generate_frontend_quests.py` · 이미지/좌표 보강 `backend/scripts/enrich_frontend_quests.py` · DB 적재 로더 `backend/app/integrations/tour_api/` |
| 영문/일문/중문간체/중문번체/독어 관광정보서비스_GW | `EngService2` / `JpnService2` / `ChsService2` / `ChtService2` / `GerService2` | 미사용 (다국어 대응 시) |
| 관광사진 정보_GW | `PhotoGalleryService1` (`gallerySearchList1` 등) | 미사용 (퀘스트 썸네일 후보) |
| 기초지자체 중심 관광지 정보 | `LocgoHubTarService1` (`areaBasedList1`, `baseYm`·`areaCd`·`signguCd` 필수) | 미사용 (지역 대표 관광지 선정 후보) |
| 관광지별 연관 관광지 정보 | `TarRlteTarService1` (`areaBasedList1`) | 미사용 (연관 퀘스트 추천 후보) |
| 지역별 관광 다양성 | data.go.kr 활용가이드 참고 | 미사용 |

### KorService2 사용법 (사용 중)

- **공통 파라미터**: `serviceKey`(인증키)·`MobileOS=ETC`·`MobileApp=ColorTrip`·`_type=json` —
  백엔드 클라이언트 `backend/app/integrations/tour_api/client.py`가 자동으로 붙인다.
- **주요 엔드포인트**
  - `areaCode2?areaCode=33` — 충북 시·군구 코드 목록
  - `areaBasedList2?areaCode=33&sigunguCode={코드}&contentTypeId={유형}` — 지역 기반 관광정보 목록
  - `searchKeyword2?keyword={장소명}&areaCode=33&sigunguCode={코드}` — 키워드 검색(이미지/좌표 보강 매칭용)
  - `detailCommon2?contentId={id}` — 공통 상세(소개문 `overview` 포함)
  - `detailIntro2?contentId={id}&contentTypeId={유형}` — 운영시간·휴무 등 소개 정보
- **contentTypeId**: 12 관광지 · 14 문화시설 · 15 축제공연행사 · 25 여행코스 · 28 레포츠 · 32 숙박 · 38 쇼핑 · 39 음식점
- **충북(areaCode=33) sigunguCode**: 괴산군 1 · 단양군 2 · 보은군 3 · 영동군 4 · 옥천군 5 · 음성군 6 ·
  제천시 7 · 진천군 8 · 청주시 10 · 충주시 11 · 증평군 12
  (9번 청원군은 2014년 청주시 통합 이전 코드 — 사용하지 않음. 백엔드 시드 매핑: `backend/app/regions/seed.py`)
- **분류코드(cat1) → 앱 퀘스트 유형 매핑**: `A01` 자연→nature · `A02` 인문(`A0201` 역사→history,
  `A0202` 휴양→healing, `A0203` 체험→active) · `A03` 레포츠→active · `A05` 음식→food
- **주의**: 발급 직후의 키는 게이트웨이 전파가 끝나기 전까지 간헐적으로 `401 Unauthorized`(본문 비표준)가
  섞여 온다 — 401도 재시도 대상으로 처리할 것. 개발계정 트래픽은 서비스당 일 1,000건.

## 관련 문서

- [인증 & 보안 · 개인정보](./auth-security.md)
- [프론트엔드 스택](./frontend.md)
