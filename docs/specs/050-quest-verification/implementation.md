# [구현 수준] 퀘스트 인증 3종 (사진 AI · 위치 · QR)

| 항목 | 내용 |
|------|------|
| 상태 | 완료 (KAN-75 dev 실동작 복구 + KAN-77 좌표 비전송 불변식 복원) |
| 최종 업데이트 | 2026-08-15 |

## 구현 규모 / 단위 분할

- **규모 판단**: 단위로 나눠 구현 — 근거: BE(비전·API)와 FE(화면 3분기)가 독립적으로 검증 가능하고, 수단별(사진/위치/QR)로도 완료 기준이 분리된다.
- **구현 단위**:
  - [x] 1) BE 비전 추상화 + verifications API + 테스트 — 키 없이 스텁 판정, 키 있으면 Gemini 판정, QR 서명 검증 pytest 통과
  - [x] 2) FE 사진 인증 실연동 — 판정 API 호출·결과 화면 실값 표시
  - [x] 3) FE 위치 인증(온디바이스) — 권한·측위·거리 판정, 좌표 비전송 확인
  - [x] 4) FE QR 인증 + QR 생성 스크립트 — 스캔→검증→완료 흐름
  - [x] 5) 권한(AndroidManifest/Info.plist)·정적 데이터 qr 전환(지역당 1개, 11개)
  - [x] 6) (KAN-73) FE 판정 연동 회귀 복원 + 사진 선택 gateway seam·위젯 테스트
  - [x] 7) (KAN-73) 사진 인증 경로 통합 — 업로드 1회 + `POST /quests/{id}/verify`가 저장본을 읽어 판정하고 `photo_verdict`를 응답에 포함. 판정 전용 라우터(`/verifications/photo`·`/verifications/qr`) 제거
  - [x] 8) (KAN-75) **dev 실동작 복구** — QR 대조 기준을 client_key로 통일, QR 퀘스트 11개 mission_type 정합화, 배포에 Gemini·QR 시크릿 주입
  - [x] 9) (KAN-77) **좌표 비전송 불변식 복원** — FE 온디바이스 판정 복원 + 좌표 파라미터 삭제, 서버가 gps 미션의 좌표를 거절, 저장된 좌표 삭제 마이그레이션
  - [x] 10) (KAN-87) **GPS 위치 도식** — 더미 플레이스홀더를 자체 렌더링 도식으로 교체(내 위치·퀘스트 지점·인증 반경), 화면 진입 시 자동 측위

## 구현된 항목

- [x] `app/integrations/vision/` — `VisionJudge` 프로토콜 + `GeminiVisionJudge`(httpx, JSON 응답 강제) + `StubVisionJudge`(키 미설정) + `get_vision_judge()` 팩토리
- [x] `app/verifications/service.py` — 사진 판정(`judge_photo`)·QR 서명 검증(`verify_qr_payload`, `hmac.compare_digest`). KAN-73에서 판정 전용 라우터·스키마를 제거하고 `POST /quests/{id}/verify`가 이 서비스를 호출한다
- [x] `app/uploads/storage.py` — `PhotoStorage.load`(로컬 `read_bytes` / GCS `download_as_bytes`)와 `object_name_from_url` 역변환. 저장된 사진으로 판정하기 위한 읽기 경로(KAN-73)
- [x] `app/quests/verification.py` — `MissionType.QR` 분기 추가(기존 gps_photo·quiz 동작 불변)
- [x] `scripts/generate_quest_qr.py` — 서명 페이로드 → QR PNG 생성(실행 검증: 11개)
- [x] FE 사진 인증 — 판정 API 연동, 결과 화면에 신뢰도·사유·제공자(stub 뱃지) 표시, 실패 시 완료 처리하지 않고 재시도 (KAN-73에서 회귀 복원 — 아래 변경 이력)
- [x] `lib/data/media/photo_picker_gateway.dart` — 사진 선택 seam(`PhotoPickerGateway`·`photoPickerGatewayProvider`). 플러그인을 화면에서 직접 부르지 않아 위젯 테스트로 인증 흐름을 검증할 수 있다(KAN-73)
- [x] FE 위치 인증 — `LocationGateway` 실측위 + `distanceMeters`(순수 하버사인) **단말 내** 판정, 서비스 꺼짐·권한 거부·영구 거부(설정 이동)·좌표 없음 안내. 반경 밖이면 서버를 부르지 않는다(KAN-77)
- [x] FE QR 인증 — mobile_scanner 스캔 → 서버 검증 → 완료
- [x] 권한 — Android `INTERNET`/`CAMERA`/`ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION`, iOS `NSLocationWhenInUseUsageDescription`
- [x] 테스트 — BE `tests/test_verifications.py`(22건: 서명 왕복·변조·타 퀘스트·판정 텍스트 파싱·업로드 검증), `tests/test_quest_verification.py`, FE `test/quest_verification_test.dart`

- [x] QR 대조 기준 = `client_key` (KAN-75) — `QuestJudgeInput.client_key` 추가, `verify_qr_payload(payload, client_key)`. 이전에는 DB UUID와 대조해 서명이 유효해도 **모든 현장 QR이 거절**됐다(생성 스크립트는 client_key로 서명)
- [x] QR 퀘스트 데이터 정합화 (KAN-75) — 마이그레이션 `c1a7e5d90b42`가 11개 퀘스트의 `mission_type`을 `qr`로 교정하고, 신규 설치용 카탈로그 스냅샷도 함께 수정. 이전에는 DB가 `photo`라 서버가 사진을 요구하며 400으로 떨어졌다
- [x] 배포 시크릿 주입 (KAN-75) — `deploy/deploy.sh`가 `GEMINI_API_KEY`·`QR_SECRET_KEY`를 Secret Manager에서 읽어 `.env`에 기록하고, 없으면 어떤 기능이 죽는지 경고한다
- [x] 인증 사진 영속화 (KAN-75) — compose `api-uploads` 볼륨 + `UPLOAD_DIR=/app/uploads`. GCS 전환 전까지 재배포에도 사진이 남는다

## 미구현 / 남은 항목

- [ ] 인증 사진의 GCS 보관 — 현재 dev는 인스턴스 볼륨(로컬 디스크)이다. 버킷 IaC와 함께 후속
- [ ] 인증 사진 보존·삭제 정책 확정 및 개인정보처리방침 반영 — 지금은 무기한 보관이고 거절분도 남는다(아래 '알려진 한계'의 보존 정책 표)
- [ ] 실제 Gemini 키로의 end-to-end 판정 확인 — 시크릿(`colortrip-dev-gemini-api-key`)은 등록됐고 키·모델 단독 호출까지 확인했다. 모델 교체(2026-08-15)를 dev에 배포한 뒤 앱에서 1회 확인이 남았다
- [ ] 현장 QR 인쇄·부착 — `scripts/generate_quest_qr.py`로 11장 생성 후 운영 절차 필요(서버와 동일한 `QR_SECRET_KEY`로 생성할 것)

## 알려진 한계 / TODO

- 온디바이스 위치 검증은 GPS 스푸핑·클라이언트 변조에 취약 — 보상/랭킹이 걸리면 서버 검증(A안) + 위치기반서비스사업 신고로 전환 검토([location-law-review.md](location-law-review.md) 체크리스트).
- (해소) 좌표 비전송 불변식 이탈 — KAN-75에서 발견하고 KAN-77에서 복원했다. 아래 변경 이력 참고.
- **인증 사진은 서버에 저장된다** — 문서가 "저장하지 않는다"로 남아 있었으나 KAN-73(업로드 1회 + 저장본 판정)부터 이미 저장하고 있었고, KAN-75의 `api-uploads` 볼륨으로 재배포에도 남게 됐다(리뷰 지적 반영). 현재 보존 정책은 아래와 같으며 **삭제 규칙이 아직 없다**.

  | 항목 | 현재 상태 |
  |------|-----------|
  | 저장 위치 | dev: 인스턴스 `api-uploads` 볼륨(`/app/uploads`). 운영: `GCS_UPLOAD_BUCKET` 설정 시 GCS |
  | 보존 기간 | **무기한** — 만료·삭제 잡이 없다 |
  | 거절된 사진 | 판정 전에 업로드하므로 **거절돼도 남는다** |
  | 접근 | 로컬 스토리지는 `/uploads/...` 경로로 서빙, GCS는 공개 읽기 버킷 전제(비공개 전환 시 signed URL 필요) |
  | 사용자 고지 | 개인정보처리방침에 인증 사진 보관 내용 **미반영** |

  → 후속 과제: 보존 기간·삭제 조건(예: 판정 후 N일, 거절분 즉시 삭제) 결정, 만료 삭제 잡, 처리방침·스토어 데이터 안전 섹션 반영. GCS 보관 정책과 함께 다룬다.
- BE `app/quests/verification.py`의 gps_photo 서버 검증 경로(`_judge_gps`)는 남아 있으나 FE는 사용하지 않는다. **이 경로를 쓰는 순간 좌표를 수신하게 되므로 위치기반서비스사업 신고가 선행되어야 한다.** gps 미션은 `_judge_gps_on_device`가 처리하며 좌표가 오면 거절한다.
- Gemini rate limit 초과 시 오류 반환(재시도 안내) — 폴백 통과 처리하지 않음.
- (해소) 사진 이중 전송 — KAN-73에서 업로드 1회 + 저장본 판정으로 통합했다. 대가로 판정 시 스토리지 읽기가 1회 발생한다(GCS는 다운로드).
- 타임아웃은 요청 성격에 맞춰 나눠 둔다 — 업로드(`/uploads/photo`)는 최대 5MB를 보내므로 `sendTimeout` 30초, 인증(`/quests/{id}/verify`)은 판정 시간 때문에 `receiveTimeout` 30초. dio 기본값에는 `sendTimeout`이 없어 전송 정체 시 무기한 대기했다(리뷰 반영).
- 비전 판정은 **DB 트랜잭션을 닫은 뒤** 수행한다 — 열어둔 채 외부 API를 기다리면 커넥션이 idle-in-transaction으로 묶여, 판정이 느릴 때 풀(기본 5+10)이 소진되고 무관한 API까지 실패한다. 판정 입력은 `QuestJudgeInput` 값 스냅샷으로 복사해 넘기고(트랜잭션을 닫으면 ORM 객체가 expire되어 async 속성 접근이 `MissingGreenlet`으로 실패), 판정 후 진행 레코드를 다시 조회해 그 사이 다른 요청이 완료했는지 확인한다. 회귀 테스트: `test_photo_verify_closes_transaction_before_vision_call`.
- 거절된 사진도 스토리지에 남는다 — 판정 전에 업로드하기 때문이다. 위 보존 정책 표 참고.

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-07-30 | 최초 작성 (KAN-58) |
| 2026-07-31 | 구현 완료. 검증에서 발견한 Gemini 판정 파싱 결함 수정 — 모델이 `"passed": "false"`(문자열)로 답하면 `bool("false")==True`라 거절이 통과로 뒤집히던 문제(회귀 테스트 추가) |
| 2026-08-13 | KAN-73 리뷰 반영(서브에이전트 리뷰) — ① 비전 판정 중 DB 트랜잭션을 닫아 커넥션 점유를 없앴다(`QuestJudgeInput` 스냅샷 + 판정 후 재조회). 제안된 "rollback 후 ORM 객체 그대로 사용"은 실측에서 `MissingGreenlet`으로 깨져 스냅샷 방식으로 구현했다. ② 사진 로드 실패를 `logger.exception`으로 남긴다(조용한 거절로 스토리지 장애를 놓치던 문제). ③ 동시 인증 폴백에서 남의 판정값을 싣지 않는다. ④ 업로드 요청에 `sendTimeout` 30초(내 이전 커밋이 타임아웃을 바이트 없는 요청 쪽에만 붙인 회귀). ⑤ 생일 휠 피커의 범위 보정이 낡은 목록으로 콜백을 되불러 월·일이 연쇄 이동하던 잠재 버그를 가드로 차단. 테스트 추가: BE 3건(트랜잭션 종료·GCS URL 역변환 2건), FE 4건(휠 보정·이탈 차단·reason 폴백·사유 초기화) |
| 2026-08-13 | **사진 인증 경로 통합(KAN-73, 사용자 요청)**: 사진을 판정용·저장용으로 두 번 보내던 구조를 없앴다. 업로드(`/uploads/photo`) 1회 후 `POST /quests/{id}/verify`가 `photo_url`로 저장본을 읽어(`PhotoStorage.load`) 비전 판정하고, 결과를 `photo_verdict`로 응답에 담는다. 판정 맥락(제목·조건)을 **서버가** 구성하므로 클라이언트가 조건을 느슨하게 바꿔 통과를 유도할 수 없다(이전 방식의 취약점). 사진을 읽지 못하거나 URL 형태가 규약과 다르면 거절(fail-closed). 미사용이 된 판정 전용 라우터·스키마(`/verifications/photo`·`/verifications/qr`)와 FE `verification_repository.dart`·`QrVerdict`를 제거하고, 라우터에 있던 과대 QR 페이로드 차단(max_length=256)은 `QuestVerifyRequest`로 옮겼다. 테스트: BE 4건(판정값 응답·거절 시 미완료·저장본 없음 거절·반경 밖 판정 생략) + 과대 페이로드 1건, FE 4건(통과·스텁 뱃지·거절·요청 실패) |
| 2026-08-13 | **dev 실동작 복구(KAN-75, 사용자 보고 "인증이 안 된다")**: 3종 중 GPS만 동작하고 있었다. ① **QR 대조 기준 불일치** — `_judge_qr`는 DB UUID와 대조하는데 `scripts/generate_quest_qr.py`는 client_key로 서명해, 유효 서명도 "이 퀘스트의 QR이 아니에요"로 거절됐다. client_key 기준으로 통일하고(인쇄물이 재시딩에도 유효), UUID 서명이 통과하지 않는 회귀 테스트를 넣었다. ② **QR 퀘스트 데이터 불일치** — FE 정적 데이터는 11개가 `verify: 'qr'`인데 DB는 전부 `mission_type='photo'`라, 앱이 QR 스캐너를 띄우고 `qr_payload`만 보내면 서버가 `photo_url`을 요구하며 400. 마이그레이션 `c1a7e5d90b42` + 카탈로그 스냅샷으로 정합화했다. 이 드리프트를 잡는 가드(`test_domain_catalog_contract`)는 이미 있었으나 **CI에 테스트 워크플로가 없어** 빨간 채로 방치돼 있었다. ③ **사진 판정 미설정** — dev `.env`에 `GEMINI_API_KEY`가 없고 `APP_ENV=dev`는 fail-closed라 사진 인증이 항상 거절됐다. `deploy.sh`에 Gemini·QR 시크릿 주입 + 미설정 경고를 넣었다(키 등록은 운영 작업으로 남음). ④ 업로드 사진이 재배포마다 사라지던 문제를 compose 볼륨으로 막았다. 테스트: BE 4건(client_key 통과·UUID 거절·client_key 없음 거절·배포 시크릿 배선) |
| 2026-08-13 | **회귀 복원(KAN-73)**: FE 사진 인증이 판정 API를 호출하지 않고 있었다 — `a3df7fc`(KAN-55 서버 영속화)에서 `domainController.uploadAndVerifyPhoto`로 통합하면서 `verificationRepository.verifyPhoto` 호출이 빠졌고, 결과 화면에 판정값을 전달하지도 않아 판정 카드가 항상 "판정 정보를 불러오지 못했어요"로 떴다(서버 `/quests/{id}/verify`는 사진 경로만 확인하므로 사실상 사진 내용 검증 없이 통과). 판정 → 통과 시 저장·완료 → 결과 화면(extra로 판정값) 순서를 복원했다. 회귀가 잡히지 않은 이유는 사진 분기에 위젯 테스트가 없어서였고, 사진 선택을 `PhotoPickerGateway` seam(`lib/data/media/photo_picker_gateway.dart`, 위치 인증의 `LocationGateway`와 같은 패턴)으로 빼서 통과·거절·판정 실패 3케이스를 `test/quest_verification_test.dart`에 추가했다 |
| 2026-08-14 | **좌표 비전송 불변식 복원(KAN-77)**: KAN-75에서 드러난 문서-코드 이탈을 코드 쪽으로 되돌렸다. `a3df7fc`(KAN-55) 이후 FE가 단말 좌표를 `lat`·`lng`로 서버에 보내고 서버가 판정했으며, `quest_progress.verified_lat/lng`에 **저장까지** 하고 있었다. law review의 결론은 B안(온디바이스)이고 그 근거는 "좌표가 단말을 벗어나지 않음"인데, 좌표는 **저장하지 않고 수신만 해도** 위치기반서비스사업 신고 대상이다(해설서 p.59~60). 신고는 이뤄지지 않았으므로 코드를 결정된 설계로 복원했다. ① FE가 `distanceMeters`(순수 하버사인)로 단말에서 판정하고 반경 이내일 때만 좌표 없이 완료를 요청한다. ② `DomainRepository.verifyQuest`·`DomainController.verifyQuest`에서 좌표 파라미터를 **삭제**했다 — 주석은 무시할 수 있지만 없는 파라미터는 보낼 수 없다. ③ 서버는 `mission_type='gps'`에 좌표가 오면 거절한다(무시하면 이탈이 조용히 반복된다). ④ 마이그레이션 `e8c3a91d7f04`로 그동안 저장된 좌표를 삭제했다(downgrade 없음). ⑤ GPS 인증 화면에 "현재 위치는 이 기기에서만 확인하고 서버로 보내지 않아요" 문구 추가. 테스트: BE 3건(좌표 거절·좌표 없이 완료·저장 안 됨), FE 3건(반경 밖 서버 미호출·반경 이내 인증·하버사인 단위) |
| 2026-08-15 | **판정 모델 교체** — dev 사진 인증이 "사진을 확인하지 못했어요"로 실패했다(판정 거절이 아니라 호출 실패 경로). 원인은 키가 아니라 모델이다: 등록된 시크릿 키로 실호출해 보면 `gemini-2.5-flash`의 `generateContent`가 404 `"This model ... is no longer available to new users"`를 반환한다. 기본 모델을 `gemini-3.5-flash`로 바꿨다 — 같은 키·같은 요청 형식으로 200 + 판정 JSON 정상 수신을 4초 간격 3회 확인했다. `GEMINI_MODEL`은 `deploy.sh`가 `.env`에 기록하지 않으므로 dev에는 코드 기본값이 그대로 쓰이고, 반영에 재배포가 필요하다. 함께: 인증 화면의 사진 미리보기가 고정 높이 120 + `BoxFit.cover`라 사진이 잘려 보이던 것을 원본 비율(`BoxFit.fitWidth`)로 바꾸고, 세로로 긴 사진이 화면을 넘치지 않도록 폼을 스크롤 영역 + 하단 고정 버튼 구조로 정리했다 |
| 2026-08-15 | **GPS 위치 도식(KAN-87)** — 인증 화면의 지도 자리가 "지도 미리보기"라고 적힌 더미 플레이스홀더여서 내 위치도 퀘스트 지점도 보이지 않았다. 외부 지도 SDK는 현재 위치 기준으로 타일을 요청해 좌표가 지도 사업자에게 전송되므로 쓸 수 없고(불변식 "단말을 벗어나면 안 된다"), `features/quests/gps_verify_map.dart`의 `CustomPainter`로 직접 그린다 — 퀘스트 지점 중심 고정 + 인증 반경 원 + 내 위치 점(반경 안/밖 색 구분) + 축척 자동 조정. 좌표→화면 변환(`questRelativeOffsetMeters`)과 축척(`mapSpanMeters`)은 순수 함수로 빼 테스트했다. 측위 시점을 **화면 진입 시 자동**으로 앞당겼다(사용자 결정) — 인증을 눌러야 측위하던 방식으로는 어느 쪽으로 얼마나 가야 하는지 인증 전에 알 수 없었다. 진입 시 측위 실패는 조용히 넘기고 퀘스트 지점·반경만 그린다(사유별 안내는 실제 인증 시도가 담당). 함께: KAN-83 리뷰 지적 반영 — 사진 미리보기가 원본 비율이 되면서 세로 사진일 때 판정 실패 사유가 폴드 밖으로 밀리던 것을 `maxHeight 320` + `BoxFit.contain`으로 막았다(상한을 두면 `fitWidth`는 `Clip.antiAlias`에 잘려 다시 crop 이 된다). 테스트: FE 4건(좌표 변환·축척·진입 시 자동 측위·측위 실패 시 화면 유지), 전체 161건 통과 |
| 2026-08-15 | **배경 지도 도입(KAN-90, 사용자 피드백 "지도가 안 보여 그냥 핀만 보이잖아")** — KAN-87의 도식은 격자 배경이라 지도로 보이지 않았다. 판단을 바로잡은 지점은 이것이다: 불변식이 막는 것은 *지도*가 아니라 **내 위치를 기준으로 타일을 요청하는 것**이다. 퀘스트 좌표는 앱에 하드코딩된 공개 데이터이므로 그 좌표로 이미지 한 장을 받는 것은 사용자 위치 전송이 아니다. ① BE `quests/static_map.py` + `GET /quests/{id}/map` — VWorld 이미지 API 호출 + 디스크 캐시. 키를 서버가 드는 이유는 APK 추출 방지와 호출 상한(퀘스트 좌표가 고정이라 캐시가 곧 상한)이다. VWorld가 오류를 200+텍스트로 주기도 해서 **PNG 시그니처 확인 후에만 캐시**한다. ② FE는 배경 이미지 위에 반경 원·내 위치를 얹고, 축척은 웹 메르카토르 공식으로 이미지와 정렬한다 — 2026-08-15 실호출로 검증했다(center를 256px에 해당하는 경도만큼 옮긴 이미지가 원본의 오른쪽 절반과 픽셀 단위 일치, 차이는 좌하단 워터마크뿐). ③ 배경은 fail-soft다 — 키 미설정·오프라인·상류 오류면 404를 주고 앱은 격자 도식으로 내려앉는다(배경은 참고용이고 인증 판정과 무관). ④ 정적 이미지는 축척이 고정이라 멀리 있으면 내 위치가 화면을 벗어나므로 가장자리 방향 삼각형으로 표시한다. 테스트: BE 7건(URL 경도·위도 순서, FE 상수와 서버 설정 일치, 키 없음, 캐시 재사용, 비-PNG 거부·미캐시, 상류 오류, 캐시 키), FE 2건(실측 축척 일치, 배경이 담는 거리) |
