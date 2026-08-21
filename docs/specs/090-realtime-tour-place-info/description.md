# [설명] 관광지 정보 실시간 조회

## 개요

퀘스트에 표시되는 관광지 데이터(썸네일 이미지·장소 소개문·운영정보)를 정적 파일이 아니라 화면 진입 시점에 한국관광공사 TourAPI에서 실시간으로 가져온다. 한국관광공사의 실시간 호출 권고(로컬 DB 저장·캐싱 지양)를 따르는 구조로, 앱에는 낡지 않는 식별자(`tourContentId`)만 남고 낡을 수 있는 공사 데이터는 저장하지 않는다. 퀘스트 골격(제목·유형·미션·보상)과 수제 퀘스트의 직접 쓴 설명, 지역 대표(히어로) 로컬 asset은 그대로다.

## 동작 방식

1. **지역 화면**: 앱이 `GET /api/v1/places?region_slug={slug}`를 호출하면, 백엔드가 TourAPI `areaBasedList2`(유형 12·14·28·39)를 호출해 `[{content_id, image_url}]`을 반환한다. 앱은 퀘스트의 `tourContentId`로 썸네일을 매칭해 표시한다.
2. **퀘스트 상세 화면**: 앱이 `GET /api/v1/places/{content_id}?content_type_id={id}`를 호출하면, 백엔드가 `detailCommon2`(이미지·소개문)와 `detailIntro2`(운영시간·휴무)를 호출해 합쳐 반환한다.
3. **사진 인증**: `POST /api/v1/quests/{id}/verify`의 사진 판정 경로에서, 퀘스트에 `content_id`가 있으면 백엔드가 `detailCommon2` 소개문을 가져와 Gemini 판정 프롬프트에 장소 맥락으로 추가한다. 조회 실패 시 기존 프롬프트 그대로 판정한다.
4. **실패 동작**: TourAPI 오류·타임아웃·한도 초과 시 백엔드는 해당 필드를 null로 응답하고, 앱은 placeholder(색 박스·기본 문구)를 표시한다. 저장된 폴백 값은 없다.

TourAPI 키는 서버만 들고, 앱은 TourAPI를 직접 호출하지 않는다.

## 주요 구성 요소 / 위치

| 구성 요소 | 역할 | 위치 |
|-----------|------|------|
| places 모듈 | TourAPI 장소 정보 프록시(엔드포인트 2개) | `backend/app/places/` |
| TourAPI 클라이언트 | KorService2 호출 래퍼(`fetch_detail_common` 포함) | `backend/app/integrations/tour_api/client.py` |
| 인증 프롬프트 보강 | 사진 판정 프롬프트에 장소 소개문 추가 | `backend/app/quests/verification.py`, `backend/app/integrations/vision/prompt.py` |
| Quest 모델 | `tourContentId`·`tourContentTypeId` 필드(정적 imageUrl·TourAPI 유래 desc 제거) | `frontend/lib/data/models/quest.dart`, `frontend/lib/data/static/quests_data.dart` |
| PlaceRepository | places 엔드포인트 호출 | `frontend/lib/data/repositories/place_repository.dart` |
| 화면 연동 | 지역·상세 화면의 실시간 로딩·placeholder 표시 | `frontend/lib/features/quests/` |

## 설정 / 사용법

* 백엔드 `TOUR_API_KEY`·`TOUR_API_BASE_URL` 환경변수 사용 — 발급·관리는 [external-apis](../../conventions/external-apis.md) 참고. 키 미설정 시 places 응답 필드가 비어 앱은 placeholder를 표시한다.
* TourAPI 엔드포인트·파라미터·쿼터 규약의 단일 출처는 [external-apis](../../conventions/external-apis.md)다.

## 예시

`GET /api/v1/places/2612497?content_type_id=12` →

```json
{
  "code": 200, "status": "OK", "message": "성공",
  "data": {
    "content_id": "2612497",
    "image_url": "https://tong.visitkorea.or.kr/cms/resource/...jpg",
    "overview": "단양팔경 중 하나인 중선암은 ...",
    "operation_info": {"usetime": "09:00~18:00", "restdate": "연중무휴"}
  }
}
```

## 관련 문서

* [external-apis 컨벤션](../../conventions/external-apis.md) — TourAPI 사용법·쿼터(SOT)
* [045-quest-region-images](../045-quest-region-images/) — 이전 정적 보강 방식(본 스펙이 대체)
* [050-quest-verification](../050-quest-verification/) — 사진 인증 흐름
