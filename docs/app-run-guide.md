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

### 개발용 토큰과 사용자 맞추기 (401이 날 때)

앱은 아직 로그인 대신 [dio_client.dart](../frontend/lib/core/network/dio_client.dart)의 **하드코딩 토큰**을 씁니다. 그 토큰의 `sub` 사용자가 **접속하려는 DB에 존재해야** 보호 API가 200을 줍니다. 없으면 전부 401이고, 앱은 정적 폴백으로 보입니다.

내 로컬 DB에 사용자를 만들고 새 토큰을 받으려면:

```bash
cd backend && docker compose exec api uv run python generate_dev_token.py
```

출력된 토큰을 `frontend/lib/core/network/dio_client.dart`의 `Authorization` 값에 붙이고 앱을 다시 빌드합니다. (커밋할 때는 팀 공용 토큰으로 되돌려 주세요 — 개인 토큰은 팀원에게 401을 유발합니다.)

> 후속 개선 후보: 토큰도 `API_BASE_URL`처럼 `--dart-define`으로 주입하면 소스 수정 없이 바꿀 수 있습니다.

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

저장소 루트에서 **debug 빌드**로 만듭니다 — 로컬 백엔드에 붙으려면 debug여야 합니다(아래 주의 참고).

```bash
docker compose -f frontend/docker-compose.yml run --rm -u 0:0 -e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0=* frontend bash -c "flutter pub get && flutter build apk --debug"
```

```bash
adb install -r frontend/build/app/outputs/flutter-apk/app-debug.apk
```

앱 서랍에서 **colortrip** 실행. debug 빌드는 Android에서 기본값이 `10.0.2.2`(에뮬레이터가 보는 호스트 머신)라 로컬 백엔드에 그대로 연결됩니다.

> **주의**: `--release`로 빌드하면 기본 주소가 **팀 dev 서버**입니다([dio_client.dart](../frontend/lib/core/network/dio_client.dart)). 릴리스 APK로 로컬 백엔드를 보려면 주소를 직접 넣으세요.
>
> ```bash
> flutter build apk --release --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
> ```

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

| 상황 | `API_BASE_URL` |
|------|----------------|
| 내 PC의 로컬 백엔드 (같은 Wi-Fi 필요) | `http://<PC의 LAN IP>:8000/api/v1` |
| 팀 dev 서버 | 생략 가능 — **release 빌드의 기본값**입니다 |
| 서버 없이 화면만 보기 | 아무 값이나(예: `http://127.0.0.1:1`) — API는 실패하고 정적 데이터로 동작 |

> 기본값은 빌드 모드로 갈립니다: **release는 팀 dev 서버**, debug/profile은 에뮬레이터 루프백(`10.0.2.2`)·`localhost`. 설치용 APK가 주소를 안 줘도 동작하게 하기 위함입니다.

### 3-1. PC의 LAN IP 확인 (로컬 백엔드에 붙일 때만)

```bash
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like '192.168.*' }
```

### 3-2. 방화벽 열기 (최초 1회, 관리자 PowerShell)

```bash
New-NetFirewallRule -DisplayName "ColorTrip API 8000" -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow
```

### 3-3. 주소를 넣어 APK 빌드

**저장소 루트에서** (`-f` 경로가 루트 기준입니다):

```bash
docker compose -f frontend/docker-compose.yml run --rm -u 0:0 -e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0=* frontend bash -c "flutter pub get && flutter build apk --release --dart-define=API_BASE_URL=http://192.168.0.3:8000/api/v1"
```

### 3-4. 핸드폰에 넣기

- **USB**: `adb install -r frontend/build/app/outputs/flutter-apk/app-release.apk`
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
| 보호 API가 모두 **401**, 지도·추천이 정적으로만 보임 | 토큰의 `sub` 사용자가 접속 대상 DB에 없음 → [토큰 맞추기](#개발용-토큰과-사용자-맞추기-401이-날-때) |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE: signatures do not match` | 다른 키로 서명된 APK가 이미 설치됨 → `adb uninstall io.vmonster.colortrip` 후 재설치 |
| 컨테이너에서 `Error: Undefined name 'Matrix4'` | pub 캐시가 사라져 `.dart_tool`이 옛 경로를 가리킴 → 명령 앞에 `flutter pub get &&` 붙이기. 상세는 [frontend/README](../frontend/README.md#캐시-볼륨--pub-get을-매번-붙이는-이유) |
| 실기기에서 서버 연결 실패 | `API_BASE_URL` 미지정(에뮬레이터 주소로 빌드됨) 또는 방화벽·Wi-Fi 불일치 → [3번](#3-내-핸드폰에-설치) |
| 컨테이너 권한 오류 | `-u 0:0`과 `GIT_CONFIG_*` 환경변수를 붙여 실행 |
| 앱을 다시 켜니 진행 상태가 사라짐 | 의도된 현재 한계 → [아래](#검증된-범위와-한계) |

---

## 검증된 범위와 한계

2026-07-31 Android 15 에뮬레이터 + 로컬 백엔드에서 다음을 실제 조작으로 확인했습니다.

- 지도 채색이 **완료 여행 수** 기준으로 동작 (여행 완주 지역만 채색, 퀘스트만 여러 개 완료한 지역은 미채색)
- 홈 DNA 추천 배너 + 퀘스트 요약 3개(TourAPI 썸네일 포함)
- 퀘스트·지역 이미지 표시, 미매칭 항목의 placeholder 폴백
- 사진 AI 인증(판정 결과 실값 표시) · 위치 인증(반경 밖 거리 안내 → 도착 시 통과) · QR 화면·권한·스캐너

알려진 한계:

- **앱을 종료하면 진행 상태(완료 퀘스트·여행·DNA)가 초기화됩니다.** 전역 상태를 메모리에만 두고 있어서이며, 서버 영속화는 후속 작업입니다. 시연 중에는 앱을 닫지 마세요.
- **QR 실제 코드 인식은 실기기에서만** 확인 가능합니다(에뮬레이터 가상 카메라 한계).
- `GEMINI_API_KEY` 미설정 시 사진 판정은 **local/test에서만** 스텁(항상 통과)이고, dev·운영에서는 거부됩니다. 실제 판정은 키 발급 후 동작합니다.
- 릴리스 APK는 **debug 키로 서명**되어 내부 테스트 설치용입니다. 스토어 업로드는 [release.md](conventions/release.md) 경로를 따릅니다.

## 관련 문서

- [frontend/README.md](../frontend/README.md) — FE 컨테이너 명령·캐시·테스트
- [backend/README.md](../backend/README.md) — BE 실행·마이그레이션·테스트
- [docs/specs/050-quest-verification/](specs/050-quest-verification/) — 인증 3종 설계와 위치정보법 검토
- [docs/conventions/release.md](conventions/release.md) — 출시·서명 경로
