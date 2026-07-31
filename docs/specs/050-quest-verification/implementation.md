# [구현 수준] 퀘스트 인증 3종 (사진 AI · 위치 · QR)

| 항목 | 내용 |
|------|------|
| 상태 | 완료 |
| 최종 업데이트 | 2026-07-31 |

## 구현 규모 / 단위 분할

- **규모 판단**: 단위로 나눠 구현 — 근거: BE(비전·API)와 FE(화면 3분기)가 독립적으로 검증 가능하고, 수단별(사진/위치/QR)로도 완료 기준이 분리된다.
- **구현 단위**:
  - [x] 1) BE 비전 추상화 + verifications API + 테스트 — 키 없이 스텁 판정, 키 있으면 Gemini 판정, QR 서명 검증 pytest 통과
  - [x] 2) FE 사진 인증 실연동 — 판정 API 호출·결과 화면 실값 표시
  - [x] 3) FE 위치 인증(온디바이스) — 권한·측위·거리 판정, 좌표 비전송 확인
  - [x] 4) FE QR 인증 + QR 생성 스크립트 — 스캔→검증→완료 흐름
  - [x] 5) 권한(AndroidManifest/Info.plist)·정적 데이터 qr 전환(지역당 1개, 11개)

## 구현된 항목

- [x] `app/integrations/vision/` — `VisionJudge` 프로토콜 + `GeminiVisionJudge`(httpx, JSON 응답 강제) + `StubVisionJudge`(키 미설정) + `get_vision_judge()` 팩토리
- [x] `app/verifications/` — `POST /verifications/photo`(multipart, 사진 비저장), `POST /verifications/qr`(HMAC-SHA256 서명 검증, `hmac.compare_digest`)
- [x] `app/quests/verification.py` — `MissionType.QR` 분기 추가(기존 gps_photo·quiz 동작 불변)
- [x] `scripts/generate_quest_qr.py` — 서명 페이로드 → QR PNG 생성(실행 검증: 11개)
- [x] FE 사진 인증 — 판정 API 연동, 결과 화면에 신뢰도·사유·제공자(stub 뱃지) 표시, 실패 시 완료 처리하지 않고 재시도
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

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-07-30 | 최초 작성 (KAN-58) |
| 2026-07-31 | 구현 완료. 검증에서 발견한 Gemini 판정 파싱 결함 수정 — 모델이 `"passed": "false"`(문자열)로 답하면 `bool("false")==True`라 거절이 통과로 뒤집히던 문제(회귀 테스트 추가) |
