# [설명] 퀘스트 인증 3종 (사진 AI · 위치 · QR)

## 개요

퀘스트 완료를 실제로 검증하는 세 가지 인증 수단. 사진 인증은 백엔드의 비전 모델(Gemini, 교체 가능)이 사진이 퀘스트 조건에 맞는지 판정하고, 위치 인증은 단말 GPS로 퀘스트 장소 반경 이내인지 **단말 내에서만** 계산하며(좌표 비전송), QR 인증은 현장에 부착된 서명 QR을 스캔해 서버가 위조 여부를 검증한다.

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

1. 화면에 들어가면 **자동으로** 위치 권한 요청(`geolocator`) → 현재 좌표 획득 → 도식에 내 위치를 표시한다(KAN-87). 인증을 눌러야 측위하던 이전 방식으로는 "어느 쪽으로 얼마나 가야 하는지"를 인증 전에 알 수 없었다. 권한은 어차피 인증에 필요하므로 요청 시점만 앞당긴 것이다.
2. 퀘스트 좌표(`lat`/`lng`, 045에서 보강)와의 하버사인 거리 계산 — 반경(`Quest.verifyRadius`, 미지정 시 `kDefaultVerifyRadiusMeters` = 500m) 이내면 통과. **이 계산은 전부 단말 안에서 수행되고 좌표는 어떤 서버로도 전송되지 않는다** (위치정보법상 신고 비대상 설계 — [location-law-review.md](location-law-review.md)).
3. 반경 이내일 때만 `POST /quests/{id}/verify`를 **좌표 없이** 호출해 완료를 기록한다. 반경 밖이면 서버를 부르지 않고 실측 거리를 안내한다. 권한 거부·위치 서비스 꺼짐·좌표 없음은 각각 안내 문구를 표시한다.

#### 위치 도식 (KAN-87)

내 위치와 퀘스트 지점의 관계를 화면에 그린다. 배경으로 **퀘스트 좌표 기준 정적 지도**를 깔고 그 위에 반경 원·내 위치를 얹는다.

문제가 되는 것은 지도 자체가 아니라 **내 위치를 기준으로 타일을 요청하는 것**이다. 지도 SDK(구글·네이버·카카오)는 현재 위치로 타일을 부르므로 좌표가 지도 사업자에게 나가지만, 퀘스트 좌표는 앱에 하드코딩된 공개 데이터이므로 그 좌표로 이미지 한 장을 받는 것은 사용자 위치 전송이 아니다. 그래서 다음을 지킨다.

| 지킬 것 | 이유 |
|---------|------|
| 지도 이미지는 **퀘스트 좌표로만** 요청 | 사용자 위치가 나가지 않는다 |
| 내 위치는 **단말이 오버레이로** 그림 | 화면 좌표로만 존재한다 |
| 지도 SDK의 "내 위치 표시"·"내 위치로 이동" **금지** | SDK가 직접 좌표를 수집·전송한다 |

이미지는 서버 프록시(`GET /quests/{id}/map`)가 VWorld에서 받아 캐시해 내려준다 — 키를 앱에 넣지 않기 위함이고, 퀘스트 좌표가 고정이라 캐시가 곧 호출 상한이 된다([external-apis.md](../../conventions/external-apis.md#vworld-gps-인증-화면의-지도-배경)).

| 요소 | 표시 |
|------|------|
| 퀘스트 지점 | 도식 **중심에 고정** + 마커 |
| 인증 반경 | 중심 기준 원(`verifyRadius`, 기본 500m) |
| 내 위치 | 실제 방위·거리에 맞춘 점 — 반경 안이면 통과 색, 밖이면 중립 색 |
| 축척 | 배경 지도가 있으면 그 이미지의 축척(웹 메르카토르)에 고정, 없으면 두 점이 보이도록 자동 조정 |
| 거리 | 실측 거리 텍스트 |
| 화면 밖 | 배경 지도는 축척이 고정이라 멀리 있으면 화면을 벗어난다 — 가장자리에 방향 삼각형으로 표시하고 거리는 칩으로 안내 |

위경도는 도식의 화면 좌표로 변환되어 painter에만 전달된다. 어떤 네트워크 호출에도 실리지 않으므로 좌표 비전송 불변식은 그대로 유지된다. 배경 이미지 URL에도 퀘스트 id만 담긴다.

**서버 설정과 FE 상수는 함께 움직인다** — 배경 지도의 줌·크기(`map_zoom`·`map_image_width/height`)를 바꾸면 앱의 축척 계산(`gps_verify_map.dart`의 `kMapZoom`·`kMapImageWidthPx`)도 같이 고쳐야 반경 원이 지도와 맞는다. 백엔드 테스트가 이 일치를 강제한다.

이 불변식은 세 겹으로 강제된다(KAN-77 — `a3df7fc`에서 좌표를 전송하도록 이탈했던 회귀를 되돌리며 추가).

| 층 | 강제 방식 |
|----|-----------|
| FE 인터페이스 | `DomainRepository.verifyQuest`에 **좌표 파라미터가 없다** — 보내려면 API를 고쳐야 하므로 실수로 새지 않는다 |
| 서버 | `mission_type='gps'`에 `lat`·`lng`가 오면 **거절**(422). 무시하면 클라이언트가 계속 보내도 아무도 모른 채 신고 대상 상태가 유지된다 |
| 테스트 | FE: 반경 밖이면 서버 미호출 / BE: 좌표 전송 거절·완료 기록에 좌표 없음 |

> 판정이 단말에 있으므로 **클라이언트 변조에 취약하다**. 이는 신고 회피를 위해 의식적으로 받아들인 트레이드오프이며(law review B안), 보상·랭킹이 생기면 서버 검증(A안) + 신고로 전환한다.

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
| 위치 도식 | 배경 지도 위에 내 위치·퀘스트 지점·인증 반경을 그린다(KAN-87·90) | `frontend/lib/features/quests/gps_verify_map.dart` |
| 배경 지도 프록시 | VWorld 정적 지도 호출 + 디스크 캐시 (`GET /quests/{id}/map`) | `backend/app/quests/static_map.py` |
| 판정 결과 화면 | 실제 AI 판정값 표시 | `frontend/lib/features/quests/photo_verify_result_screen.dart` |
| 사진 선택 seam | 갤러리·카메라 선택(테스트에서 대체 가능) | `frontend/lib/data/media/photo_picker_gateway.dart` |

## 설정 / 사용법

```bash
# backend/.env
GEMINI_API_KEY=   # local·test는 비우면 스텁 판정(항상 통과), dev·운영은 비우면 항상 거절
GEMINI_MODEL=gemini-3.5-flash
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
# 시크릿 등록 (최초 1회). 값이 셸 히스토리에 남지 않도록 표준입력으로 넣고,
# printf '%s'로 **개행 없이** 저장한다 — 개행이 섞이면 헤더·서명 값이 깨진다.
gcloud secrets create colortrip-dev-gemini-api-key --project colortrip --replication-policy=automatic
read -rs GEMINI_KEY && printf '%s' "$GEMINI_KEY" \
  | gcloud secrets versions add colortrip-dev-gemini-api-key --project colortrip --data-file=- \
  && unset GEMINI_KEY

# QR 서명 키는 값을 직접 만들 필요 없이 랜덤 생성한다.
gcloud secrets create colortrip-dev-qr-secret-key --project colortrip --replication-policy=automatic
openssl rand -base64 32 | tr -d '\n' \
  | gcloud secrets versions add colortrip-dev-qr-secret-key --project colortrip --data-file=-

# 확인 — 두 시크릿 모두 버전이 1개 이상이어야 한다.
gcloud secrets versions list colortrip-dev-gemini-api-key --project colortrip
gcloud secrets versions list colortrip-dev-qr-secret-key --project colortrip
```

> QR 시크릿을 등록하지 않으면 `deploy.sh`가 경고 후 `JWT_SECRET_KEY` 파생값으로 진행한다. 이 경우 **JWT 키를 교체하는 순간 현장에 붙인 QR 11장이 전부 무효화**되므로, QR을 인쇄하기 전에 반드시 등록할 것.

## 예시

- 사진 인증 결과 화면: "통과 — 신뢰도 87% · 도담삼봉 전경이 사진에서 확인됩니다." (`verify` 응답의 `photo_verdict`)
- 위치 인증 실패: "퀘스트 장소에서 약 2.4km 떨어져 있어요 (인증 반경 500m)".
- QR 검증 실패: "이 퀘스트의 QR이 아니에요."

## 관련 문서

- [plan.md](plan.md) · [implementation.md](implementation.md) · [location-law-review.md](location-law-review.md)
- 여정·인증(기존 GPS·사진·퀴즈 BE): [docs/specs/010-journey/](../010-journey/)
