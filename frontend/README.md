# ColorTrip Frontend (다채로울지도)

Flutter 앱 실행·빌드 가이드. 프로젝트 전체 개요는 [루트 README](../README.md), 규약은 [docs/conventions/frontend.md](../docs/conventions/frontend.md)를 보세요.

> **앱을 켜서 만져보는 것이 목적이라면** 백엔드 준비·토큰 맞추기·데모 팁·문제 해결까지 한 번에 정리된 **[docs/app-run-guide.md](../docs/app-run-guide.md)** 를 보세요. 이 문서는 FE 툴체인(컨테이너 명령·캐시·테스트) 레퍼런스입니다.

이 저장소는 **Flutter SDK가 없는 머신에서도** `frontend/Dockerfile`(cirruslabs/flutter — **Android SDK 포함**)로 빌드·테스트할 수 있게 되어 있습니다. 아래 명령은 모두 `frontend/` 디렉토리 기준입니다.

## 빠른 확인 (웹)

```bash
docker compose run --rm frontend flutter pub get
docker compose run --rm --service-ports frontend flutter run -d web-server --web-hostname=0.0.0.0 --web-port=5000
```

- 접속: <http://localhost:5000>
- 참고: 바인드 마운트 권한 문제가 나면 아래 [권한 문제](#권한-문제--u-00)처럼 `-u 0:0`을 붙이세요.

## Android 에뮬레이터로 실행

컨테이너(Linux)는 Windows의 USB/에뮬레이터를 볼 수 없으므로 **빌드는 컨테이너, 실행·설치는 호스트(Windows)** 로 나눠 진행합니다.

### 1. 에뮬레이터 준비 (최초 1회)

1. [Android Studio](https://developer.android.com/studio) 설치 (Windows).
2. Android Studio → **Device Manager** → *Create Virtual Device* → 기기(예: Pixel 8) 선택 → 시스템 이미지(API 34+ 권장) 다운로드 → 생성.
3. `adb`는 Android Studio에 포함됩니다(`%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`). PATH에 추가해두면 편합니다.

### 2. APK 빌드 (컨테이너)

```bash
docker compose run --rm -u 0:0 -e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0=* frontend bash -c "flutter pub get && flutter build apk --debug --dart-define=KAKAO_NATIVE_APP_KEY=<native-app-key> --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1"
```

- 결과물(호스트에 바로 생성): `build/app/outputs/flutter-apk/app-debug.apk`
- 최초 빌드는 Gradle·Android 의존성 다운로드로 오래 걸립니다(수 분~수십 분). 이후는 캐시로 빨라집니다.

### 3. 에뮬레이터에 설치·실행

Device Manager에서 에뮬레이터를 시작한 뒤:

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

앱 서랍에서 **colortrip** 실행.

### 4. 로컬 백엔드 연결

- 에뮬레이터 안에서 호스트 머신은 `10.0.2.2`입니다. 빌드할 때 `API_BASE_URL=http://10.0.2.2:8000/api/v1`를 명시하세요.
- 백엔드를 먼저 띄우세요: `cd backend && docker compose up` ([backend/README.md](../backend/README.md)).
- 인증은 카카오 로그인으로 받은 access token을 ColorTrip 세션으로 교환합니다. `KAKAO_NATIVE_APP_KEY`와 `API_BASE_URL`을 빌드 설정으로 제공해야 하며, 정적 Bearer token은 사용하지 않습니다.

### 5. 기능별 에뮬레이터 데모 팁

| 기능 | 방법 |
|------|------|
| 위치 인증 | 에뮬레이터 우측 툴바 **⋯(Extended Controls) → Location**에서 퀘스트 좌표를 입력 후 *Set location*. 퀘스트 좌표는 [lib/data/static/quests_data.dart](lib/data/static/quests_data.dart)의 `lat`/`lng` |
| 사진 인증 | Extended Controls → Camera로 가상 장면 사용, 또는 갤러리에 이미지를 드래그해 넣고 갤러리에서 선택 |
| QR 인증 | `cd backend && uv run python scripts/generate_quest_qr.py`로 QR PNG 생성 → 모니터에 띄우고 에뮬레이터 카메라(webcam 설정 시) 또는 실기기로 스캔 |

> 실기기 테스트는 아래 [실기기(내 핸드폰)에 설치](#실기기내-핸드폰에-설치) 참고 — 빌드 시 `--dart-define=API_BASE_URL=...`로 주소를 지정합니다(LAN IP 결정 근거: [infra-deploy.md](../docs/conventions/infra-deploy.md)).

## 실기기(내 핸드폰)에 설치

에뮬레이터용 기본 주소(`10.0.2.2`)는 **실기기에서 접속되지 않습니다.** 실기기는 아래 중 하나로 API 주소를 정해 빌드하세요.

| 상황 | `API_BASE_URL` | 빌드 모드 |
|------|----------------|----------|
| 팀 dev 서버에 붙이기 (권장) | `https://34-64-226-70.sslip.io/api/v1` | debug · release 모두 |
| 내 PC의 로컬 백엔드에 붙이기 (같은 Wi-Fi 필요) | `http://<PC의 LAN IP>:8000/api/v1` | **debug만** |
| 서버 없이 화면만 보기 | 닿지 않는 주소(예: `http://127.0.0.1:1`) | debug |

**기본값은 없습니다.** `KAKAO_NATIVE_APP_KEY`와 `API_BASE_URL`을 둘 다 `--dart-define`으로 주지 않으면 앱이 설정 오류 화면으로 뜹니다([app_config.dart](lib/core/config/app_config.dart)). 릴리스는 Gradle이 키 없이 빌드를 거부합니다.

**릴리스 빌드는 평문 HTTP를 통신하지 못합니다** — `targetSdk=36`에 `usesCleartextTraffic` 미설정이라 Android가 cleartext를 차단합니다. 로컬 백엔드(HTTP)를 볼 때는 debug를 쓰세요. 배경: [065-dev-https](../docs/specs/065-dev-https/)

```bash
docker compose run --rm -u 0:0 -e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0=* frontend bash -c "flutter pub get && flutter build apk --release --dart-define=KAKAO_NATIVE_APP_KEY=<native-app-key> --dart-define=API_BASE_URL=https://api.example.com/api/v1"
```

1. **PC의 LAN IP 확인** (Windows PowerShell): `Get-NetIPAddress -AddressFamily IPv4` — `192.168.x.x` 항목.
2. **방화벽 허용** — 처음엔 PC 방화벽이 8000 포트를 막습니다. 관리자 PowerShell에서 한 번만:
   ```bash
   New-NetFirewallRule -DisplayName "ColorTrip API 8000" -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow
   ```
3. **APK를 핸드폰으로 전송** — USB(`adb install -r <apk>`), 또는 카카오톡/구글 드라이브로 파일 전송 후 핸드폰에서 열기.
4. **알 수 없는 앱 설치 허용** — 안드로이드가 차단하면 안내에 따라 해당 앱(파일 관리자/카톡)의 설치 권한을 허용합니다.
5. 앱을 열어 권한 요청(위치·카메라)을 허용하면 위치·QR 인증을 실제로 쓸 수 있습니다.

> iOS(아이폰)는 개발자 계정 서명이 필요해 이 방식으로 설치할 수 없습니다 — 출시 경로는 [release.md](../docs/conventions/release.md).

## Mac에서 실행

Mac에는 Flutter를 직접 설치하는 편이 가장 간단합니다(Docker도 위 명령 그대로 동작합니다).

```bash
brew install --cask flutter android-studio   # Flutter SDK + Android Studio
cd frontend && flutter pub get
flutter devices                              # 연결된 기기·시뮬레이터 확인
flutter run                                  # 기기/에뮬레이터에서 실행
flutter run -d chrome                        # 웹으로 빠르게 확인
```

- **Android 에뮬레이터**: Android Studio → Device Manager에서 AVD 생성 후 `flutter run`. 로컬 백엔드는 `10.0.2.2`로 자동 연결됩니다.
- **iOS 시뮬레이터**(Mac 전용): `sudo xcodebuild -license accept` 후 `open -a Simulator` → `flutter run`. 로컬 백엔드는 `localhost`로 연결됩니다.
- 백엔드는 Mac에서도 `cd backend && docker compose up`으로 띄울 수 있습니다.

## APK 빌드 (설치용)

```bash
docker compose run --rm -u 0:0 -e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0=* frontend bash -c "flutter pub get && flutter build apk --release --dart-define=KAKAO_NATIVE_APP_KEY=<native-app-key> --dart-define=API_BASE_URL=https://34-64-226-70.sslip.io/api/v1"
```

- 결과물: `build/app/outputs/flutter-apk/app-release.apk` (약 83MB, 빌드 ~7분)
- 정식 출시 빌드·서명은 Codemagic 경로를 따릅니다: [docs/conventions/release.md](../docs/conventions/release.md).

### 서명

`android/key.properties`가 있으면 그 릴리스 키로 서명하고, **없으면 debug 키로 폴백**하며 경고를 출력합니다. 폴백 산출물은 내부 테스트 설치용이고 **스토어 업로드는 불가**합니다.

```bash
cp android/key.properties.example android/key.properties   # 값 채워서 사용
```

키스토어와 `key.properties`는 커밋되지 않습니다(`.gitignore`). **키스토어를 분실하면 앱 업데이트가 영구 불가**하니 생성 후 반드시 백업하세요. 상세: [070-release-signing](../docs/specs/070-release-signing/).

카카오 로그인용 키 해시는 빌드된 APK에서 직접 뽑는 게 정확합니다.

```bash
docker compose run --rm -u 0:0 frontend bash -c "/opt/android-sdk-linux/build-tools/36.0.0/apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk"
```

출력된 SHA-1을 base64로 변환한 값이 카카오 콘솔에 넣을 키 해시입니다 — `echo "<SHA-1>" | tr -d ':' | xxd -r -p | openssl base64`
- 참고: 로컬 백엔드(http) 통신은 debug manifest에서만 허용됩니다. release 빌드는 **반드시 HTTPS** API 주소를 사용해야 합니다.

## 테스트·정적 분석

```bash
docker compose run --rm frontend flutter analyze
docker compose run --rm frontend flutter test
docker compose run --rm frontend dart format .
```

## 권한 문제 (`-u 0:0`)

Dockerfile 기본 사용자(UID 1000)가 바인드 마운트·Gradle/pub 캐시에 쓰기 실패하는 경우가 있습니다. 그때는 위 APK 빌드 명령처럼 `-u 0:0`(root)과 `GIT_CONFIG_*=safe.directory` 환경변수를 붙여 실행하세요(`.claude/launch.json`의 `frontend-web`도 같은 우회를 씁니다).

## 캐시 볼륨 · `pub get`을 매번 붙이는 이유

`docker compose run`은 매번 **새 컨테이너**를 만들기 때문에 컨테이너 내부에 받아둔 pub/Gradle 캐시가 종료와 함께 사라집니다. 반면 `.dart_tool/package_config.json`(호스트에 남는 파일)은 사라진 캐시 경로를 계속 가리켜, 다음 실행에서 이런 오류가 납니다.

```text
Error: Undefined name 'Matrix4'.  (flutter SDK 내부 파일에서 발생)
```

두 가지로 방지합니다.

- `docker-compose.yml`에 `pub-cache`·`gradle-cache` **명명 볼륨**을 두어 캐시를 유지합니다(이 저장소에 이미 설정됨).
- 그래도 각 명령 앞에 `flutter pub get &&`을 붙이는 것을 권장합니다(의존성 변경 반영 + package_config 재생성).

캐시를 완전히 비우려면: `docker compose down -v` 후 다시 `flutter pub get`.
