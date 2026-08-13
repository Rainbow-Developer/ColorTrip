# [구현 수준] 퀘스트 인증 3종 (사진 AI · 위치 · QR)

| 항목 | 내용 |
|------|------|
| 상태 | 완료 (KAN-73: FE 판정 연동 회귀 복원 + 사진 인증 경로 통합) |
| 최종 업데이트 | 2026-08-13 |

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

## 구현된 항목

- [x] `app/integrations/vision/` — `VisionJudge` 프로토콜 + `GeminiVisionJudge`(httpx, JSON 응답 강제) + `StubVisionJudge`(키 미설정) + `get_vision_judge()` 팩토리
- [x] `app/verifications/service.py` — 사진 판정(`judge_photo`)·QR 서명 검증(`verify_qr_payload`, `hmac.compare_digest`). KAN-73에서 판정 전용 라우터·스키마를 제거하고 `POST /quests/{id}/verify`가 이 서비스를 호출한다
- [x] `app/uploads/storage.py` — `PhotoStorage.load`(로컬 `read_bytes` / GCS `download_as_bytes`)와 `object_name_from_url` 역변환. 저장된 사진으로 판정하기 위한 읽기 경로(KAN-73)
- [x] `app/quests/verification.py` — `MissionType.QR` 분기 추가(기존 gps_photo·quiz 동작 불변)
- [x] `scripts/generate_quest_qr.py` — 서명 페이로드 → QR PNG 생성(실행 검증: 11개)
- [x] FE 사진 인증 — 판정 API 연동, 결과 화면에 신뢰도·사유·제공자(stub 뱃지) 표시, 실패 시 완료 처리하지 않고 재시도 (KAN-73에서 회귀 복원 — 아래 변경 이력)
- [x] `lib/data/media/photo_picker_gateway.dart` — 사진 선택 seam(`PhotoPickerGateway`·`photoPickerGatewayProvider`). 플러그인을 화면에서 직접 부르지 않아 위젯 테스트로 인증 흐름을 검증할 수 있다(KAN-73)
- [x] FE 위치 인증 — geolocator 실측위 + `distanceBetween` **단말 내** 판정, 서비스 꺼짐·권한 거부·영구 거부(설정 이동)·좌표 없음 안내
- [x] FE QR 인증 — mobile_scanner 스캔 → 서버 검증 → 완료
- [x] 권한 — Android `INTERNET`/`CAMERA`/`ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION`, iOS `NSLocationWhenInUseUsageDescription`
- [x] 테스트 — BE `tests/test_verifications.py`(22건: 서명 왕복·변조·타 퀘스트·판정 텍스트 파싱·업로드 검증), `tests/test_quest_verification.py`, FE `test/quest_verification_test.dart`

## 미구현 / 남은 항목

- [ ] 인증 사진의 서버 보관(GCS) — 판정만 하고 저장하지 않는다(후속)
- [ ] 실제 Gemini 키로의 end-to-end 판정 확인 — 현재 로컬·테스트는 스텁 경로만 검증(키 미설정)

## 알려진 한계 / TODO

- 온디바이스 위치 검증은 GPS 스푸핑·클라이언트 변조에 취약 — 보상/랭킹이 걸리면 서버 검증(A안) + 위치기반서비스사업 신고로 전환 검토([location-law-review.md](location-law-review.md) 체크리스트).
- 인증 사진은 서버에 저장하지 않는다(타임라인 사진은 FE 세션 메모리 보관 유지). GCS 업로드 연동은 후속.
- BE `app/quests/verification.py`의 gps_photo 서버 검증 경로는 남아 있으나 FE는 사용하지 않는다(좌표 비전송 설계). 서버 검증 전환 시에만 사용할 것.
- Gemini rate limit 초과 시 오류 반환(재시도 안내) — 폴백 통과 처리하지 않음.
- (해소) 사진 이중 전송 — KAN-73에서 업로드 1회 + 저장본 판정으로 통합했다. 대가로 판정 시 스토리지 읽기가 1회 발생한다(GCS는 다운로드). 판정 시간이 인증 응답에 포함되므로 FE는 사진 인증 요청에만 타임아웃을 30초로 늘려 호출한다.
- 거절된 사진도 스토리지에 남는다 — 판정 전에 업로드하기 때문이다. 정리(만료 삭제)는 GCS 보관 정책과 함께 다룰 후속 과제.

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-07-30 | 최초 작성 (KAN-58) |
| 2026-07-31 | 구현 완료. 검증에서 발견한 Gemini 판정 파싱 결함 수정 — 모델이 `"passed": "false"`(문자열)로 답하면 `bool("false")==True`라 거절이 통과로 뒤집히던 문제(회귀 테스트 추가) |
| 2026-08-13 | **사진 인증 경로 통합(KAN-73, 사용자 요청)**: 사진을 판정용·저장용으로 두 번 보내던 구조를 없앴다. 업로드(`/uploads/photo`) 1회 후 `POST /quests/{id}/verify`가 `photo_url`로 저장본을 읽어(`PhotoStorage.load`) 비전 판정하고, 결과를 `photo_verdict`로 응답에 담는다. 판정 맥락(제목·조건)을 **서버가** 구성하므로 클라이언트가 조건을 느슨하게 바꿔 통과를 유도할 수 없다(이전 방식의 취약점). 사진을 읽지 못하거나 URL 형태가 규약과 다르면 거절(fail-closed). 미사용이 된 판정 전용 라우터·스키마(`/verifications/photo`·`/verifications/qr`)와 FE `verification_repository.dart`·`QrVerdict`를 제거하고, 라우터에 있던 과대 QR 페이로드 차단(max_length=256)은 `QuestVerifyRequest`로 옮겼다. 테스트: BE 4건(판정값 응답·거절 시 미완료·저장본 없음 거절·반경 밖 판정 생략) + 과대 페이로드 1건, FE 4건(통과·스텁 뱃지·거절·요청 실패) |
| 2026-08-13 | **회귀 복원(KAN-73)**: FE 사진 인증이 판정 API를 호출하지 않고 있었다 — `a3df7fc`(KAN-55 서버 영속화)에서 `domainController.uploadAndVerifyPhoto`로 통합하면서 `verificationRepository.verifyPhoto` 호출이 빠졌고, 결과 화면에 판정값을 전달하지도 않아 판정 카드가 항상 "판정 정보를 불러오지 못했어요"로 떴다(서버 `/quests/{id}/verify`는 사진 경로만 확인하므로 사실상 사진 내용 검증 없이 통과). 판정 → 통과 시 저장·완료 → 결과 화면(extra로 판정값) 순서를 복원했다. 회귀가 잡히지 않은 이유는 사진 분기에 위젯 테스트가 없어서였고, 사진 선택을 `PhotoPickerGateway` seam(`lib/data/media/photo_picker_gateway.dart`, 위치 인증의 `LocationGateway`와 같은 패턴)으로 빼서 통과·거절·판정 실패 3케이스를 `test/quest_verification_test.dart`에 추가했다 |
