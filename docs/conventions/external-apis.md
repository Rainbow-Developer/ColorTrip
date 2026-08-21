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
| 퀘스트·지역 이미지 | 퀘스트 썸네일은 TourAPI `firstimage` CDN URL 핫링크, 지역 대표(히어로) 이미지는 로컬 asset | [045 스펙](../specs/045-quest-region-images/) |
| 여행 DNA 추천 | 룰 기반으로 시작 | |
| API 키 / 쿼터 관리 | 환경변수 + GCP Secret Manager | |

## 규칙 / 적용

- 관광·행사 데이터는 TourAPI를 사용한다.
- 백엔드 지도/지역 데이터는 Naver API를 사용한다.
- 사진 인증은 Gemini 비전 판정을 쓰되 `app/integrations/vision/`의 인터페이스 뒤에 두고, 키 미설정 시 스텁으로 동작한다. DNA 추천은 룰 기반 유지.
- API 키는 환경변수 + GCP Secret Manager로 관리한다.

## Gemini (사진 AI 인증)

- **용도**: 퀘스트 인증 사진이 조건에 맞는지 판정 (`backend/app/integrations/vision/`). 호출 지점은 `POST /api/v1/quests/{id}/verify` — 업로드된 사진을 읽어 판정한다([050-quest-verification](../specs/050-quest-verification/)).
- **키**: [Google AI Studio](https://aistudio.google.com/apikey)에서 발급 → 로컬 `backend/.env`의 `GEMINI_API_KEY`, 운영은 Secret Manager(생성 시 [deploy/deploy.sh](../../deploy/deploy.sh)에 반영 필요). 모델은 `GEMINI_MODEL`(기본 `gemini-3.5-flash`).
- **미설정 시**: 스텁 판정(항상 통과 + "AI 미설정" 사유) — 데모·테스트는 키 없이 동작한다.
- **쿼터**: 무료 티어는 분당 요청 제한이 있어 초과 시 오류를 그대로 반환한다(폴백 통과 처리하지 않음).

## VWorld (GPS 인증 화면의 지도 배경)

- **용도**: GPS 인증 화면에 깔 정적 지도 이미지. 호출 지점은 `GET /api/v1/quests/{id}/map` — 서버가 VWorld를 부르고 결과를 디스크에 캐시한다(`backend/app/quests/static_map.py`).
- **키**: [VWorld 오픈API 신청](https://www.vworld.kr/dev/v4api.do)에서 활용 API **"이미지 API"** 로 발급 → 로컬 `backend/.env`의 `VWORLD_API_KEY`, dev는 Secret Manager `colortrip-dev-vworld-api-key`([deploy/deploy.sh](../../deploy/deploy.sh)).
- **키를 앱이 아니라 서버가 든다**: ① 앱에 넣으면 APK에서 추출된다 ② GPS 퀘스트는 좌표가 고정이라 서버 캐시가 곧 호출 상한이 된다(앱이 직접 부르면 사용자 수만큼 나간다).
- **좌표 비전송 불변식**: 지도는 **퀘스트 좌표로만** 요청한다. 사용자 위치는 이 경로에 들어오지 않고, 단말이 받은 이미지 위에 오버레이로 그린다. 지도 SDK의 "내 위치 표시"나 "내 위치로 이동"을 쓰면 좌표가 지도 사업자에게 나가므로 **금지**한다([location-law-review.md](../specs/050-quest-verification/location-law-review.md)).
- **요청 형식**(2026-08-15 실호출 검증): `GET {base}/req/image?service=image&request=getmap&key=…&format=png&basemap=GRAPHIC&center={경도},{위도}&crs=EPSG:4326&zoom=…&size={w},{h}`. **center는 경도,위도 순서**다.
- **축척**: 웹 메르카토르 표준 `156543.03392 × cos(위도) / 2^zoom`을 따른다(실측 확인 — center를 256px에 해당하는 경도만큼 옮긴 이미지가 원본의 절반과 픽셀 단위로 일치). 앱의 오버레이가 같은 공식을 쓰므로 **서버의 `map_zoom`·`map_image_width/height`를 바꾸면 FE 상수(`gps_verify_map.dart`)도 함께 고쳐야 한다** — 백엔드 테스트가 이 일치를 강제한다.
- **미설정 시**: 지도 배경 없이 도식만 그린다(fail-soft). 배경은 참고용이고 인증 판정과 무관하다.
- **주의**: VWorld는 오류를 200 + 텍스트로 돌려주기도 한다. PNG 시그니처를 확인한 뒤에만 캐시한다(안 그러면 깨진 응답이 캐시에 눌러앉는다). 이미지 좌하단의 워터마크는 저작권 표시이므로 가리거나 잘라내지 않는다.

## TourAPI 활용신청 현황 (공공데이터포털, 2026-07-17 승인 · 2028-07-17 만료)

하나의 data.go.kr 계정 인증키로 아래 **11건이 개발계정으로 승인**되어 있고, 그중 **실제로 호출하는 것은 국문 관광정보 서비스(`KorService2`) 1건뿐**이다. 나머지 10건은 나중에 쓸 여지를 두고 신청만 해둔 상태다.
키는 로컬 `backend/.env`의 `TOUR_API_KEY`로 주입하고, 운영은 Secret Manager
`colortrip-dev-tour-api-key`로 관리한다(현재 시크릿 미생성 — 생성 시 dev 서버 배포에 자동 반영,
[deploy/deploy.sh](../../deploy/deploy.sh) 참고).

**호출량 확인**: 우리 코드에는 호출 횟수를 집계하는 곳이 없다(로그도 `serviceKey`를 마스킹한다). 실제 사용량은 data.go.kr → 마이페이지 → 오픈 API → 개발계정에서 해당 활용신청 건의 상세를 열어 확인한다.

| 서비스(활용신청 명) | Base URL (`apis.data.go.kr/B551011/…`) | 상태 |
|------|------|------|
| 국문 관광정보 서비스_GW | `KorService2` | **사용 중**(유일) — 아래 [KorService2 사용법](#korservice2-사용법-사용-중) 참고 |
| 영문/일문/중문간체/중문번체/독어 관광정보서비스_GW | `EngService2` / `JpnService2` / `ChsService2` / `ChtService2` / `GerService2` | 미사용 (다국어 대응 시) |
| 관광사진 정보_GW | `PhotoGalleryService1` (`gallerySearchList1` 등) | 미사용 (퀘스트 썸네일 후보) |
| 기초지자체 중심 관광지 정보 | `LocgoHubTarService1` (`areaBasedList1`, `baseYm`·`areaCd`·`signguCd` 필수) | 미사용 (지역 대표 관광지 선정 후보) |
| 관광지별 연관 관광지 정보 | `TarRlteTarService1` (`areaBasedList1`) | 미사용 (연관 퀘스트 추천 후보) |
| 지역별 관광 다양성 | data.go.kr 활용가이드 참고 | 미사용 |
| 관광공모전(사진) 수상작 정보 | data.go.kr 활용가이드 참고 | 미사용 (지역 대표 이미지 후보 — 수상작은 저작자 표시 조건을 먼저 확인할 것) |

### KorService2 사용법 (사용 중)

- **공통 파라미터**: `serviceKey`(인증키)·`MobileOS=ETC`·`MobileApp=ColorTrip`·`_type=json` — 호출하는 각 코드가 붙인다.
- **호출 지점**: 관광지 데이터(이미지·소개문·운영정보)는 서버가 요청 시점에 실시간 조회한다 — 공사 권고(로컬 저장·캐싱 지양) 준수, [090 스펙](../specs/090-realtime-tour-place-info/) 참고. **앱은 TourAPI를 직접 호출하지 않는다**(키는 서버만 든다 — VWorld와 같은 논리).

  | 엔드포인트 | 호출하는 곳 | 용도 |
  |------|------|------|
  | `areaBasedList2?areaCode=33&sigunguCode={코드}&contentTypeId={유형}` | `backend/app/places/`(런타임, `GET /api/v1/places?region_slug=`) · 스크립트 2종 | 지역 관광지 목록 — 런타임은 썸네일 맵, 스크립트는 후보 수집·매칭 |
  | `detailCommon2?contentId={id}` | `backend/app/places/`(런타임, `GET /api/v1/places/{content_id}`) · 사진 인증 프롬프트 보강(`app/quests/verification.py`) · `generate_frontend_quests.py` | 공통 상세 — 이미지·소개문(`overview`) |
  | `detailIntro2?contentId={id}&contentTypeId={유형}` | `backend/app/places/`(런타임) | 운영시간·휴무 — 유형별 필드를 (usetime, restdate)로 정규화 |
  | `areaCode2?areaCode=33` | `generate_frontend_quests.py` · `enrich_frontend_quests.py` · `backfill_tour_content_ids.py` | 충북 시·군구 코드 목록 |
  | `searchKeyword2?keyword={장소명}` | `enrich_frontend_quests.py` · `backfill_tour_content_ids.py` | 키워드 검색 — 매칭 보충 |

  런타임 호출량: 지역 화면 진입 1회 = `areaBasedList2` 4건, 상세 화면 1회 = `detailCommon2`+`detailIntro2` 2건, 사진 인증 1회 = `detailCommon2` 1건. 캐시하지 않으므로(공사 권고) 사용자 수에 비례한다 — 일 한도(아래 '주의') 초과 시 앱은 placeholder로 동작한다. 스크립트는 1회 실행당 약 100~300건.
- **미연결 코드**: `backend/app/integrations/tour_api/loader.py`(`load_quests_for_region` — DB 적재)는 정의만 있고 호출하는 코드가 없다. 되살릴지 걷어낼지는 미정.
- **파라미터 주의**
  - `searchKeyword2?keyword={장소명}` — **areaCode/sigunguCode를 주면 0건이 반환**되므로(법정동 코드 전환 영향) 파라미터 없이 호출하고 응답의 `addr1`/legacy 코드로 클라이언트에서 필터링한다
  - `detailIntro2` 응답의 운영정보 필드명은 유형별로 다르다(12 `usetime`/`restdate` · 14 `usetimeculture`/… · 28 `usetimeleports`/… · 39 `opentimefood`/`restdatefood`) — 정규화는 `backend/app/places/service.py`
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
