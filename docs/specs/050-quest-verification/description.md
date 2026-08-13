# [설명] 퀘스트 인증 3종 (사진 AI · 위치 · QR)

## 개요

퀘스트 완료를 실제로 검증하는 세 가지 인증 수단. 사진 인증은 백엔드의 비전 모델(Gemini, 교체 가능)이 사진이 퀘스트 조건에 맞는지 판정하고, 위치 인증은 단말 GPS 좌표로 퀘스트 장소 반경 이내인지 계산하며, QR 인증은 현장에 부착된 서명 QR을 스캔해 서버가 위조 여부를 검증한다.

> ⚠️ 위치 인증의 판정 위치(단말 vs 서버)는 **현재 문서와 코드가 어긋나 있고 결정이 필요하다**. 아래 "위치 기반 인증" 절과 [implementation.md](implementation.md)의 알려진 한계를 함께 읽을 것.

## 동작 방식

### 사진 AI 인증 (`verify: 'photo'`)

1. 사용자가 갤러리/카메라로 사진 선택 → FE가 `POST /api/v1/uploads/photo`로 **사진을 한 번만** 올려 `photo_url`을 받고, 그 URL로 `POST /api/v1/quests/{id}/verify`를 호출한다.
2. BE는 저장된 사진을 스토리지에서 읽어(`PhotoStorage.load`) `VisionJudge`에 넘긴다 — `GEMINI_API_KEY` 설정 시 Gemini(`generateContent`, 이미지 inline)로 `{passed, confidence, reason}` JSON을 받고, 미설정 시 `StubVisionJudge`가 통과 처리(사유에 "AI 미설정" 명시). local·test 외 환경에서 키가 없으면 `UnavailableVisionJudge`가 **거부**한다(fail-closed).
3. **판정 맥락은 서버가 만든다** — 퀘스트 제목과 `mission_meta`(판정 프롬프트·조건 목록), 없으면 설명을 쓴다. 클라이언트가 조건을 보내지 않으므로 조건을 느슨하게 바꿔 통과를 유도할 수 없다.
4. 통과하면 완료를 기록하고, 판정 상세를 `verify` 응답의 `photo_verdict`(passed·confidence·reason·provider)로 함께 내려준다 → FE가 결과 화면에 실제 신뢰도·사유·"AI 미설정" 뱃지를 표시. 거절이면 완료를 기록하지 않고 인증 화면에 사유를 남겨 재시도한다.
5. 사진을 읽지 못하거나(파일 없음·스토리지 오류) `photo_url`이 스토리지 규약과 다르면 **거절**한다 — 판정 없이 통과시키지 않는다.

> 사진 인증은 `POST /quests/{id}/verify` **한 경로**로만 수행한다. 판정 전용 엔드포인트
> (`POST /verifications/photo`)는 같은 사진을 두 번 보내야 해서 제거했고(KAN-73), 판정 로직
> (`verifications/service.judge_photo`)은 그대로 이 경로가 호출한다.

### 위치 기반 인증 (`verify: 'gps'`)

1. "현재 위치로 인증하기" → 위치 권한 요청(`geolocator`) → 현재 좌표 획득.
2. 퀘스트 좌표와의 하버사인 거리 계산 — 인증 반경(`verify_radius`, DB 기본 200m) 이내면 통과.
   - **설계 의도**: 계산을 전부 단말에서 하고 좌표는 서버로 보내지 않는다(위치정보법상 신고 비대상 설계 — [location-law-review.md](location-law-review.md)).
   - **현재 코드**: 단말 좌표를 `lat`·`lng`로 서버에 보내고 **서버가** 판정한다(`a3df7fc`, KAN-55). 즉 위 전제가 지금은 성립하지 않는다. 어느 쪽으로 확정할지는 미결 — [implementation.md](implementation.md) 참고.
3. 실패 시 현재 거리를 안내. 권한 거부·위치 서비스 꺼짐·좌표 없음은 각각 안내 문구 표시.

### QR 인증 (`verify: 'qr'`)

1. 현장 QR에는 `colortrip:quest:{client_key}:{HMAC-SHA256 서명 16자}` 페이로드가 담긴다 (`scripts/generate_quest_qr.py`로 생성).
2. FE `mobile_scanner`로 스캔 → 스캔한 페이로드를 `POST /api/v1/quests/{id}/verify`의 `qr_payload`로 전송.
3. BE가 서명을 재계산해 위조 여부를, 페이로드의 식별자와 대상 퀘스트의 `client_key` 일치로 다른 퀘스트 QR 여부를 검증한 뒤 통과 시 완료를 기록한다(서명 검증은 `verifications/service.verify_qr_payload` 재사용).

**식별자는 DB UUID가 아니라 `client_key`(`dy3` 등)다** — FE 정적 데이터와 공유하는 안정적인 키라 퀘스트 행을 재시딩해 UUID가 바뀌어도 인쇄해 붙인 QR이 계속 유효하다. `client_key`가 없는 QR 퀘스트는 데이터 오류로 보고 거절한다(fail-closed).

#### QR 운영 (발급·교체)

| 항목 | 내용 |
|------|------|
| 서명 키 | Secret Manager `colortrip-dev-qr-secret-key` → `QR_SECRET_KEY`. **JWT 키와 분리**한다 — 파생값을 쓰면 JWT 교체 때 현장 QR이 전량 무효화된다 |
| 발급 | `uv run python scripts/generate_quest_qr.py` → `backend/qr_output/{client_key}.png` 11장(시·군당 1개). 인쇄해 현장 부착 |
| 만료 | 없음(고정 서명). 재발급은 시크릿 새 버전 = **전량 재출력**이므로 키 유출 시에만 |
| 알려진 한계 | 고정 QR은 사진으로 복제하면 현장에 가지 않고도 인증할 수 있다. 보상·랭킹이 생기면 GPS 병행 검증 또는 회전 코드로 강화 검토 |

## 주요 구성 요소 / 위치

| 구성 요소 | 역할 | 위치 |
|-----------|------|------|
| VisionJudge 추상화 | Gemini/스텁 판정 교체 지점 | `backend/app/integrations/vision/` |
| 판정·검증 로직 | 사진 판정(`judge_photo`)·QR 서명 검증(`verify_qr_payload`) | `backend/app/verifications/service.py` |
| 인증 진입점 | `POST /quests/{id}/verify` — 미션별 판정 + 완료 기록 | `backend/app/quests/verification.py` · `service.py` |
| 사진 읽기 | 저장된 인증 사진 로드(`PhotoStorage.load`)·URL 역변환 | `backend/app/uploads/storage.py` |
| DB 퀘스트 인증 확장 | MissionType.QR·비전 연동 | `backend/app/quests/verification.py` |
| QR 생성 | 서명 페이로드 → PNG | `backend/scripts/generate_quest_qr.py` |
| 인증 화면 3분기 | 사진 업로드·GPS 측위·QR 스캔 | `frontend/lib/features/quests/quest_verify_screen.dart` |
| 판정 결과 화면 | 실제 AI 판정값 표시 | `frontend/lib/features/quests/photo_verify_result_screen.dart` |
| 사진 선택 seam | 갤러리·카메라 선택(테스트에서 대체 가능) | `frontend/lib/data/media/photo_picker_gateway.dart` |

## 설정 / 사용법

```bash
# backend/.env
GEMINI_API_KEY=   # local·test는 비우면 스텁 판정(항상 통과), dev·운영은 비우면 항상 거절
GEMINI_MODEL=gemini-2.5-flash
QR_SECRET_KEY=    # 비우면 JWT_SECRET_KEY에서 파생(권장하지 않음 — 위 QR 운영 표)

# QR 이미지 생성 (개발 의존성 필요: uv sync --group dev)
cd backend
uv run python scripts/generate_quest_qr.py dy3 cj4 ...   # 인자 없으면 정적 QR 퀘스트 11개 전부
```

dev 서버는 이 두 값을 Secret Manager에서 읽어 주입한다(`deploy/deploy.sh`). 시크릿이 없으면 배포는 계속되지만 어떤 기능이 죽는지 경고 로그를 남긴다.

| 환경변수 | Secret Manager 시크릿 | 없을 때 |
|----------|----------------------|---------|
| `GEMINI_API_KEY` | `colortrip-dev-gemini-api-key` | `APP_ENV=dev`는 fail-closed — 사진 인증이 **항상 거절**된다 |
| `QR_SECRET_KEY` | `colortrip-dev-qr-secret-key` | `JWT_SECRET_KEY` 파생값 사용 — JWT 교체 시 현장 QR 전량 무효 |

```bash
# 시크릿 등록 (최초 1회, 값은 표준입력으로 넣어 셸 히스토리에 남기지 않는다)
gcloud secrets create colortrip-dev-gemini-api-key --project colortrip --replication-policy automatic
gcloud secrets versions add colortrip-dev-gemini-api-key --project colortrip --data-file -
```

## 예시

- 사진 인증 결과 화면: "통과 — 신뢰도 87% · 도담삼봉 전경이 사진에서 확인됩니다." (`verify` 응답의 `photo_verdict`)
- 위치 인증 실패: "퀘스트 장소에서 약 2.4km 떨어져 있어요 (인증 반경 500m)".
- QR 검증 실패: "이 퀘스트의 QR이 아니에요."

## 관련 문서

- [plan.md](plan.md) · [implementation.md](implementation.md) · [location-law-review.md](location-law-review.md)
- 여정·인증(기존 GPS·사진·퀴즈 BE): [docs/specs/010-journey/](../010-journey/)
