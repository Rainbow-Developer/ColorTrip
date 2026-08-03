# [계획] 퀘스트 인증 3종 (사진 AI · 위치 · QR)

| 항목 | 내용 |
|------|------|
| 기능명 | 퀘스트 인증 3종 (사진 AI / 온디바이스 위치 / QR) |
| Spec 폴더 | `docs/specs/050-quest-verification/` |
| 영역 | 공통 (backend + frontend) |
| 작성자 | Claude Code (KAN-58) |
| 작성일 | 2026-07-30 |
| 상태 | 계획 |

## 배경 / 목적

퀘스트 인증 UI는 사진/GPS/퀴즈 3분기가 있지만 전부 스텁이다 — 사진은 선택만 하면 통과(결과 화면의 "AI 94%"는 하드코딩), GPS는 가짜 진행바, 실측위 없음. 실제로 동작하는 인증 3종을 구현한다: ① 사진 AI 인증(비전 모델 판정) ② 위치 기반 인증(실제 GPS, 단말 내 거리 검증) ③ QR 인증(현장 QR 스캔).

## 목표 (Goals)

- 사진 인증: 업로드된 사진을 비전 모델(Gemini)이 퀘스트 맥락으로 판정하고, 결과 화면에 실제 판정값(통과 여부·신뢰도·사유)을 표시한다.
- 위치 인증: 단말 GPS로 실측위하여 퀘스트 좌표와의 거리로 판정한다. **좌표는 서버로 전송하지 않는다**(위치정보법 설계 — [location-law-review.md](location-law-review.md)).
- QR 인증: 서버 서명(HMAC) 페이로드 QR을 스캔해 서버 검증으로 판정한다. QR 이미지 생성 스크립트를 제공한다.
- 판정 제공자는 교체 가능한 인터페이스로 두고, API 키가 없으면 스텁 판정으로 동작한다.

## 비목표 (Non-Goals)

- FE 퀘스트 카탈로그의 BE 전환(정적 데이터 유지 — 000-frontend-app 결정).
- GPS 스푸핑·앱 변조 방어(서버 검증 전환 시 재검토).
- OX 퀴즈 인증 변경(기존 유지).
- 인증 사진의 서버 보관(GCS 업로드) — 판정만 하고 저장하지 않는다(후속).

## 요구사항

- 사진 판정 실패 시 사유를 보여주고 재시도 가능해야 한다.
- 위치 권한 거부·서비스 꺼짐·좌표 없는 퀘스트에 대한 안내 UX가 있어야 한다.
- QR 페이로드는 위·변조를 서버가 판별할 수 있어야 한다(서명).
- 오프라인/서버 미가동 시: 사진·QR 인증은 실패 안내(완료 처리 금지), 위치 인증은 온디바이스라 동작.

## 설계 개요 / 접근 방식

### backend

- **비전 판정 추상화** `app/integrations/vision/`(신규): `VisionJudge` 프로토콜(`judge(image_bytes, mime, prompt) -> VisionVerdict{passed, confidence, reason}`), 구현체 `GeminiVisionJudge`(httpx로 `generativelanguage.googleapis.com` `generateContent`, inline_data base64, JSON 응답 강제)와 `StubVisionJudge`(키 미설정 시 — 통과 처리 + "AI 미설정" 사유). 설정: `GEMINI_API_KEY`(빈값 허용), `GEMINI_MODEL`(기본 `gemini-2.5-flash`).
- **스테이트리스 인증 API** `app/verifications/`(신규 도메인, 보호): FE 정적 카탈로그용이라 DB 퀘스트를 참조하지 않는다.
  - `POST /api/v1/verifications/photo` — multipart(image) + form(title, place, conditions) → 비전 판정 결과. 이미지는 판정 후 저장하지 않음.
  - `POST /api/v1/verifications/qr` — `{payload, quest_id}` → 서명 검증 결과. 페이로드 형식 `colortrip:quest:{quest_id}:{hmac_sha256_hex16}`, 키는 `QR_SECRET_KEY`(미설정 시 `JWT_SECRET_KEY`에서 파생).
- **DB 퀘스트 경로 확장** `app/quests/verification.py`: `MissionType.QR` 추가·판정 분기, `gps_photo` 판정에 비전 판정 연동(옵션: `mission_meta.judgement_prompt` 존재 시). 기존 동작 하위호환.
- **QR 생성 스크립트** `scripts/generate_quest_qr.py`: 퀘스트 id 목록 → 서명 페이로드 → PNG(qrcode, dev 의존성) 출력.

### frontend

- `pubspec.yaml`: `geolocator`, `mobile_scanner` 추가.
- `VerificationRepository`(dio, 신규): photo 판정·QR 검증 API 호출.
- `quest_verify_screen.dart`:
  - photo: 기존 image_picker 유지 → "인증하기" 시 API 판정 → 통과 시 `completeQuest`, 결과 화면에 실제 판정값 전달. 실패 시 사유 + 재선택.
  - gps: `geolocator`로 권한 요청·현재 위치 획득(진행 UI) → 하버사인 거리 ≤ `quest.verifyRadius`(기본 500m) 판정 — **전 과정 단말 내 처리, 서버 호출 없음**. 성공 시 완료, 실패 시 거리 표시.
  - qr(신규 분기): `mobile_scanner` 카메라 스캔 → 페이로드 서버 검증 → 성공 시 완료.
- `photo_verify_result_screen.dart`: 하드코딩 지표 제거, 판정 결과(신뢰도·사유·판정 시각) 표시.
- 정적 데이터: 각 지역 1개 퀘스트를 `verify: 'qr'`로 전환(11개, 보강 스크립트에서 함께 처리), `verifyLabels`에 qr 추가.
- Android 권한: `INTERNET`(main — 현재 debug에만 있어 릴리스 APK 필수), `CAMERA`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`. iOS `Info.plist`: 카메라·사진·위치(WhenInUse) 사용 설명.

## 의사결정 (함께 논의 · 근거 필수)

| 결정할 항목 | 선택지 | 제안 / 근거 | 상태 |
|------|--------|------------|------|
| 비전 모델 | Claude API / **Gemini** / 스텁만 | **Gemini**(사용자 선택). AI Studio 무료 티어 + 팀이 GCP 사용 중. httpx 직접 호출로 신규 의존성 0. 인터페이스 뒤에 숨겨 제공자 교체 가능, 키 없으면 스텁 폴백 | 합의됨 |
| 위치 검증 위치 | 서버 검증(A) / **온디바이스(B)** | **온디바이스**(사용자 선택). 좌표가 서버에 닿으면 위치기반서비스사업 신고 대상(미신고 형사처벌) — 단말 내 처리는 방통위 해설서상 신고 비대상. 상세: [location-law-review.md](location-law-review.md). 스푸핑 취약은 MVP 수용 | 합의됨 |
| QR 서명 방식 | 서명 없는 평문 / HMAC 서명 / 서버 발급 일회용 토큰 | **HMAC-SHA256(16자 절단)**. 평문은 아무나 QR 재생성 가능. 일회용 토큰은 현장 인쇄물과 안 맞음(정적 인쇄 전제). HMAC은 시크릿 없이 위조 불가 + 표준 라이브러리로 구현 | 합의됨(구현 승인) |
| 사진 저장 여부 | GCS 업로드 후 판정 / 판정만(비저장) | **판정만**. 저장은 uploads 도메인·GCS 버킷 미구성 상태라 별도 작업. 개인정보 최소화에도 부합. 타임라인 사진은 기존대로 FE 메모리 보관 | 합의됨(구현 승인) |

## 영향 범위

- backend: `app/integrations/vision/`(신규), `app/verifications/`(신규), `app/core/enums.py`, `app/core/config.py`, `app/quests/verification.py`, `app/quests/schemas.py`, `app/main.py`, `scripts/generate_quest_qr.py`(신규), `pyproject.toml`(dev: qrcode), `.env.example`, `tests/`(verifications·vision·qr)
- frontend: `pubspec.yaml`, `lib/data/repositories/verification_repository.dart`(신규), `lib/state/repository_providers.dart`, `lib/features/quests/quest_verify_screen.dart`, `photo_verify_result_screen.dart`, `lib/core/constants.dart`, `lib/data/static/quests_data.dart`(qr 전환), `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`
- 문서: README(환경변수·의존성·기능표), [external-apis.md](../../conventions/external-apis.md)(Gemini 추가), 본 spec

## 작업 단계

- [ ] BE: vision 추상화 + verifications 도메인 + enums/config + QR 스크립트 + 테스트
- [ ] FE: 의존성·권한 + verify 3분기 실구현 + 결과 화면 + 테스트
- [ ] 데이터: QR 퀘스트 11개 전환(045 스크립트와 함께)

## 리스크 / 미해결 질문

- Gemini 무료 티어 rate limit(분당 요청 제한) — 데모 규모에선 문제없음, 초과 시 스텁 폴백이 아닌 오류 반환(사용자 재시도).
- 에뮬레이터는 GPS 모의 위치를 쓰므로 위치 인증 데모는 에뮬레이터 확장 컨트롤로 좌표를 설정해 시연한다(문서화).
