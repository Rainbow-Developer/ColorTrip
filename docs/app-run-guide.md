# 앱 실행·설치 가이드 (에뮬레이터 · Mac · 실기기)

다채로울지도 앱을 **직접 켜서 만져보기 위한 런북**입니다. 환경별로 필요한 것만 따라가면 됩니다.

- 프론트엔드 툴체인(analyze·test·캐시 함정 등) 상세는 [frontend/README.md](../frontend/README.md)
- 백엔드 실행 옵션 상세는 [backend/README.md](../backend/README.md)
- 에뮬레이터에서 확인된 동작 범위는 [검증 결과](#검증된-범위와-한계) 참고

## 0. 공통 — 백엔드 먼저 띄우기

앱의 지도 동기화·여행 DNA·홈 추천·퀘스트 인증은 백엔드가 필요합니다. 서버가 없으면 앱은 **정적 데이터로 동작**하고 해당 기능만 조용히 폴백합니다(화면은 깨지지 않습니다).

```bash
cd backend && docker compose up -d --wait
```

최초 1회는 스키마·지역 데이터를 준비합니다.

```bash
docker compose exec api uv run alembic upgrade head
docker compose exec api uv run python -m app.regions.seed
```

홈 추천을 실제로 보려면 퀘스트 데이터도 필요합니다(TourAPI 호출, 수 분 소요).

```bash
docker compose exec api uv run python -m app.integrations.tour_api.loader
```

확인: <http://localhost:8000/docs> (Swagger) · <http://localhost:8000/health>

### 팀 dev 서버를 쓸 수도 있습니다

로컬 백엔드를 띄우기 싫으면 팀 dev 서버를 그대로 쓰면 됩니다. HTTPS로 서비스됩니다.

```bash
curl https://colortrip.p-e.kr/health
```

| 대상 | `API_BASE_URL` | 빌드 모드 |
|------|----------------|----------|
| 팀 dev 서버 (HTTPS) | `https://colortrip.p-e.kr/api/v1` | debug · release 모두 가능 |
| 로컬 백엔드 (HTTP) | `http://10.0.2.2:8000/api/v1` | **debug만** — release는 평문 차단 |

### 인증은 카카오 로그인입니다

예전의 하드코딩 Bearer 토큰은 **없어졌습니다.** 앱은 카카오 로그인으로 받은 access token을 ColorTrip 세션으로 교환하고, 이후 refresh까지 자동 처리합니다([auth_session_interceptor.dart](../frontend/lib/core/network/auth_session_interceptor.dart)).

따라서 **빌드할 때 `--dart-define` 2개가 필수**입니다. 하나라도 빠지면 앱이 설정 오류 화면으로 뜹니다([app_config.dart](../frontend/lib/core/config/app_config.dart)).

| 이름 | 설명 |
|------|------|
| `KAKAO_NATIVE_APP_KEY` | 카카오 개발자 콘솔의 네이티브 앱 키 (`backend/.env` 참고) |
| `API_BASE_URL` | 접속할 API 주소 (위 표) |

---

## 1. Windows PC — Android 에뮬레이터로 실행

Flutter SDK가 없어도 됩니다. **빌드는 Docker 컨테이너, 실행·설치는 Windows**로 나눠 진행합니다(컨테이너는 Linux라 에뮬레이터를 보지 못합니다).

### 1-1. 최초 준비

1. [Android Studio](https://developer.android.com/studio) 설치.
2. **Device Manager → Create Virtual Device** → 기기(예: Pixel 8) → 시스템 이미지 API 34+ → 생성.
3. `adb`·`emulator`는 `%LOCALAPPDATA%\Android\Sdk\`에 있습니다. PATH에 넣어두면 편합니다.

### 1-2. 에뮬레이터 켜기

```bash
& "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" -avd <AVD이름>
```

### 1-3. APK 빌드 후 설치

저장소 루트에서 빌드합니다. **로컬 백엔드(HTTP)에 붙으려면 반드시 debug 빌드**여야 합니다(아래 주의 참고).

```bash
docker compose -f frontend/docker-compose.yml run --rm -u 0:0 -e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0=* frontend bash -c "flutter pub get && flutter build apk --debug --dart-define=KAKAO_NATIVE_APP_KEY=<native-app-key> --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1"
```

```bash
adb install -r frontend/build/app/outputs/flutter-apk/app-debug.apk
```

앱 서랍에서 **colortrip** 실행. 에뮬레이터 안에서 호스트 머신은 `10.0.2.2`입니다.

팀 dev 서버(HTTPS)에 붙일 거라면 릴리스 빌드도 됩니다.

```bash
docker compose -f frontend/docker-compose.yml run --rm -u 0:0 -e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0=* frontend bash -c "flutter pub get && flutter build apk --release --dart-define=KAKAO_NATIVE_APP_KEY=<native-app-key> --dart-define=API_BASE_URL=https://colortrip.p-e.kr/api/v1"
```

> **주의 — 릴리스 빌드는 평문 HTTP를 통신하지 못합니다.** `targetSdk=36`인데 메인 매니페스트에 `usesCleartextTraffic`이 없어 Android가 cleartext를 차단합니다(`network_security_config`는 debug 매니페스트에만 있습니다). 즉 릴리스 APK로는 **로컬 백엔드(`http://...`)에 절대 붙지 않습니다.** 로컬을 보려면 debug를 쓰고, 릴리스는 HTTPS 주소(dev 서버)로만 빌드하세요. 배경: [065-dev-https](specs/065-dev-https/)

---

## 2. Mac에서 실행

Mac에서는 Flutter를 직접 설치하는 편이 가장 간단합니다(위 Docker 명령도 그대로 동작합니다).

```bash
brew install --cask flutter android-studio
```

```bash
cd frontend && flutter pub get && flutter devices
```

```bash
flutter run
```

| 대상 | 방법 | 백엔드 주소 |
|------|------|------------|
| Android 에뮬레이터 | Android Studio → Device Manager에서 AVD 생성 후 `flutter run` | `10.0.2.2` 자동 |
| iOS 시뮬레이터 (Mac 전용) | `open -a Simulator` 후 `flutter run` | `localhost` 자동 |
| 웹(빠른 확인) | `flutter run -d chrome` | `localhost` 자동 |
| 실기기 | 아래 [3번](#3-내-핸드폰에-설치) 참고 | 주소 주입 필요 |

백엔드도 Mac에서 `cd backend && docker compose up -d --wait`로 띄울 수 있습니다.

---

## 3. 내 핸드폰에 설치

에뮬레이터 기본 주소(`10.0.2.2`)는 **실기기에서 접속되지 않습니다.** 빌드할 때 API 주소를 지정하세요.

| 상황 | `API_BASE_URL` | 빌드 모드 |
|------|----------------|----------|
| 팀 dev 서버 (가장 쉬움) | `https://colortrip.p-e.kr/api/v1` | debug · release 모두 |
| 내 PC의 로컬 백엔드 (같은 Wi-Fi 필요) | `http://<PC의 LAN IP>:8000/api/v1` | **debug만** (평문) |
| 서버 없이 화면만 보기 | 닿지 않는 주소(예: `http://127.0.0.1:1`) | debug |

> **기본값은 없습니다.** `KAKAO_NATIVE_APP_KEY`와 `API_BASE_URL` 둘 다 `--dart-define`으로 주지 않으면 앱이 설정 오류 화면으로 뜹니다. 릴리스 빌드는 `KAKAO_NATIVE_APP_KEY`가 없으면 Gradle이 아예 빌드를 거부합니다(서명 키가 아니라 카카오 앱 키입니다).
>
> 실기기로 팀 dev 서버를 쓰는 게 가장 간단합니다 — HTTPS라 릴리스 빌드가 그대로 붙고, LAN IP·방화벽 설정이 필요 없습니다.

### 3-0. 팀 dev 서버로 빌드 (권장)

```bash
docker compose -f frontend/docker-compose.yml run --rm -u 0:0 -e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0=* frontend bash -c "flutter pub get && flutter build apk --release --dart-define=KAKAO_NATIVE_APP_KEY=<native-app-key> --dart-define=API_BASE_URL=https://colortrip.p-e.kr/api/v1"
```

아래 3-1 ~ 3-3은 **로컬 백엔드에 붙일 때만** 필요합니다.

### 3-1. PC의 LAN IP 확인 (로컬 백엔드에 붙일 때만)

```bash
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like '192.168.*' }
```

### 3-2. 방화벽 열기 (최초 1회, 관리자 PowerShell)

```bash
New-NetFirewallRule -DisplayName "ColorTrip API 8000" -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow
```

### 3-3. 주소를 넣어 APK 빌드 (로컬 백엔드용 — debug)

**저장소 루트에서** (`-f` 경로가 루트 기준입니다):

`<PC의-LAN-IP>`는 [3-1](#3-1-pc의-lan-ip-확인-로컬-백엔드에-붙일-때만)에서 확인한 값으로 바꾸세요.

```bash
docker compose -f frontend/docker-compose.yml run --rm -u 0:0 -e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0=* frontend bash -c "flutter pub get && flutter build apk --debug --dart-define=KAKAO_NATIVE_APP_KEY=<native-app-key> --dart-define=API_BASE_URL=http://<PC의-LAN-IP>:8000/api/v1"
```

로컬 백엔드는 평문 HTTP라 **release가 아니라 debug**로 빌드해야 합니다.

### 3-4. 핸드폰에 넣기

설치할 파일은 **어느 쪽으로 빌드했는지에 따라 다릅니다.**

| 빌드 | 설치할 APK |
|------|-----------|
| [3-0](#3-0-팀-dev-서버로-빌드-권장) 팀 dev 서버 (release) | `app-release.apk` |
| [3-3](#3-3-주소를-넣어-apk-빌드-로컬-백엔드용--debug) 로컬 백엔드 (debug) | `app-debug.apk` |

- **USB**: `adb install -r frontend/build/app/outputs/flutter-apk/<위 표의 APK>`
- **무선**: APK를 카카오톡 나에게 보내기·구글 드라이브로 옮긴 뒤 핸드폰에서 파일을 열기

안드로이드가 "알 수 없는 앱" 설치를 막으면 안내에 따라 해당 앱(파일 관리자·카카오톡)의 설치 권한을 허용합니다. 앱 실행 후 위치·카메라 권한을 허용하면 위치·QR 인증을 실제로 쓸 수 있습니다.

> **아이폰은 이 방식으로 설치할 수 없습니다** — 개발자 계정 서명이 필요합니다. 출시 경로는 [release.md](conventions/release.md)(Android 우선 · Codemagic → Play 내부 테스트).

---

## 4. 기능별 데모 팁

| 기능 | 방법 |
|------|------|
| **위치 인증** | 에뮬레이터: 우측 툴바 **⋯(Extended Controls) → Location**에 퀘스트 좌표 입력 후 *Set location*. 좌표는 [quests_data.dart](../frontend/lib/data/static/quests_data.dart)의 `lat`/`lng`. 실기기: 실제로 그 장소에 있어야 통과(반경 500m) |
| **사진 AI 인증** | 에뮬레이터: `adb push <사진> /sdcard/Pictures/` 후 미디어 스캔(`adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Pictures/<파일>`) → 앱에서 갤러리 선택. `GEMINI_API_KEY`가 없으면 **APP_ENV=local/test에서만** 스텁 판정(항상 통과 + "AI 미설정" 사유)이 뜹니다. dev·운영에서는 거부됩니다(fail-closed) |
| **QR 인증** | `cd backend && uv run python scripts/generate_quest_qr.py` 로 QR PNG 생성 → 모니터에 띄우고 **실기기**로 스캔. 에뮬레이터 가상 카메라로는 인식할 수 없습니다 |
| **지도 채색** | 한 지역의 선택 퀘스트를 **전부** 완료해 여행을 완주하면 그 지역이 칠해집니다(5회 완주 시 최대 채도 — 1회마다 한 단계씩 진해집니다). 퀘스트를 몇 개 완료해도 여행을 완주하지 않으면 칠해지지 않습니다 |

---

## 5. 자주 겪는 문제

| 증상 | 원인 · 해결 |
|------|------------|
| 앱이 **설정 오류 화면**으로 뜸 | `KAKAO_NATIVE_APP_KEY` 또는 `API_BASE_URL` `--dart-define` 누락 → [인증은 카카오 로그인입니다](#인증은-카카오-로그인입니다) |
| 릴리스 빌드가 `KAKAO_NATIVE_APP_KEY is required` 로 실패 | Gradle이 릴리스 빌드에서 키를 강제합니다 → `--dart-define`으로 전달 |
| **릴리스** APK에서 모든 네트워크 요청 실패 | 평문 HTTP 주소로 빌드함. 릴리스는 cleartext 차단 → HTTPS 주소로 빌드하거나 debug 빌드 사용 |
| 보호 API가 모두 **401** | 카카오 로그인을 하지 않았거나 세션 만료 → 앱에서 다시 로그인 |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE: signatures do not match` | 다른 키로 서명된 APK가 이미 설치됨 → `adb uninstall io.vmonster.colortrip` 후 재설치 |
| 컨테이너에서 `Error: Undefined name 'Matrix4'` | pub 캐시가 사라져 `.dart_tool`이 옛 경로를 가리킴 → 명령 앞에 `flutter pub get &&` 붙이기. 상세는 [frontend/README](../frontend/README.md#캐시-볼륨--pub-get을-매번-붙이는-이유) |
| 실기기에서 서버 연결 실패 | 로컬 백엔드를 쓰는 중이면 방화벽·Wi-Fi 확인. 팀 dev 서버(HTTPS)로 빌드하면 이 문제가 없습니다 → [3-0번](#3-0-팀-dev-서버로-빌드-권장) |
| 컨테이너 권한 오류 | `-u 0:0`과 `GIT_CONFIG_*` 환경변수를 붙여 실행 |

---

## 검증된 범위와 한계

2026-07-31 Android 15 에뮬레이터 + 로컬 백엔드에서 다음을 실제 조작으로 확인했습니다.

- 지도 채색이 **완료 여행 수** 기준으로 동작 (여행 완주 지역만 채색, 퀘스트만 여러 개 완료한 지역은 미채색)
- 홈 DNA 추천 배너 + 퀘스트 요약 3개(TourAPI 썸네일 포함)
- 퀘스트·지역 이미지 표시, 미매칭 항목의 placeholder 폴백
- 사진 AI 인증(판정 결과 실값 표시) · 위치 인증(반경 밖 거리 안내 → 도착 시 통과) · QR 화면·권한·스캐너

2026-08-06에는 dev 서버 HTTPS 적용([065-dev-https](specs/065-dev-https/))과 함께 다음을 확인했습니다.

- `https://colortrip.p-e.kr/health` 200, Let's Encrypt 인증서 유효(만료 2026-11-04), HTTP→HTTPS 308 리다이렉트
- dev 서버 라우트 29개 정상 등록(이전 배포 실패로 4개에 멈춰 있던 상태 해소)
- 릴리스 APK가 HTTPS dev 서버 주소로 빌드·설치·기동

알려진 한계:

- **QR 실제 코드 인식은 실기기에서만** 확인 가능합니다(에뮬레이터 가상 카메라 한계).
- `GEMINI_API_KEY` 미설정 시 사진 판정은 **local/test에서만** 스텁(항상 통과)이고, dev·운영에서는 거부됩니다. 실제 판정은 키 발급 후 동작합니다.
- 릴리스 APK는 **debug 키로 서명**되어 내부 테스트 설치용입니다. 스토어 업로드는 [release.md](conventions/release.md) 경로를 따릅니다.

## 관련 문서

- [frontend/README.md](../frontend/README.md) — FE 컨테이너 명령·캐시·테스트
- [backend/README.md](../backend/README.md) — BE 실행·마이그레이션·테스트
- [docs/specs/050-quest-verification/](specs/050-quest-verification/) — 인증 3종 설계와 위치정보법 검토
- [docs/conventions/release.md](conventions/release.md) — 출시·서명 경로
