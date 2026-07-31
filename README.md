# ColorTrip

**다채로울지도(ColorTrip)** 는 충청북도 11개 시·군을 여행 퀘스트로 탐험하고, 완료한 지역을 지도 위에 색칠해 나가는 모바일 앱입니다. **backend(Python) + frontend(Flutter)** 를 함께 관리하는 모노레포입니다.

> AI 코딩 에이전트로 작업한다면 먼저 [docs/AGENT_GUIDE.md](docs/AGENT_GUIDE.md)를 읽으세요.

## 주요 기능

### 🎯 핵심 기능

<!-- 사용자/도메인 관점의 핵심 기능. 상세 동작은 각 기능 스펙의 description.md를 SOT로 둔다. -->
- **여행 퀘스트·지도 색칠**: 카카오로 시작 → 여행 DNA 진단(초기 설문) → 시·군별 퀘스트를 사진·GPS·OX퀴즈로 인증 → 완료할수록 지도가 진하게 칠해짐. 타임라인·공유 카드로 기록. (상세: [docs/specs/000-frontend-app/description.md](docs/specs/000-frontend-app/description.md))
- **Kakao 인증·회원**: 백엔드는 Kakao access token의 발급 앱을 검증하고 JWT·프로필·버전 동의·즉시 익명화 탈퇴를 제공한다. Flutter SDK·세션·설문 연동은 후속 KAN-54에서 제공한다. (상세: [docs/specs/035-kakao-auth-integration/](docs/specs/035-kakao-auth-integration/))
- **여행 DNA별 퀘스트**: 설문으로 파악한 여행 성향(자연탐험·미식·역사문화·액티비티·힐링 5종)에 맞춰 충북 11개 시·군의 퀘스트를 추천
- **GPS·사진 기반 퀘스트 인증**: 퀘스트 완료 시 GPS로 현재 위치를 확인하고, 사진 인증으로 실제 방문 여부를 검증
- **지도 색칠 / 방문 기록 시각화**: 퀘스트를 완료한 지역을 지도에 색칠하고, 방문 깊이에 따라 색의 채도가 진해지는 수집형 경험
- **여행 결과 공유**: 색칠한 지도와 여행 DNA 결과를 타임라인으로 기록하고 이미지로 공유

### 🏗️ 아키텍처 특징

- **모노레포**: backend(Python)와 frontend(Flutter)를 한 저장소에서 관리
- **프론트엔드 단독 구동(현재)**: 백엔드 연동 전까지 프론트엔드는 정적 데이터 + 메모리 상태로 동작(Repository 인터페이스로 후속 API 교체 seam 확보). 자세한 결정은 [docs/specs/000-frontend-app/plan.md](docs/specs/000-frontend-app/plan.md).

## 요구사항

- **Python**: 3.13 ([docs/conventions/backend.md](docs/conventions/backend.md))
- **Flutter / Dart**: Flutter 3.44+ / Dart 3.12+
- **패키지 매니저**: 백엔드 — uv / 프론트엔드 — pub
- 외부 키: 현재 프론트엔드 단독 구동에는 불필요(카카오 로그인 스텁·정적 데이터). 후속 연동 시 [인증·보안](docs/conventions/auth-security.md)·[외부 API](docs/conventions/external-apis.md) 컨벤션 참고.
- **관광 공공데이터 기반**: 한국관광공사 TourAPI로 관광지·행사·운영정보를 받아 퀘스트로 가공 ([docs/conventions/external-apis.md](docs/conventions/external-apis.md))
- **외부 의존**: PostgreSQL · 한국관광공사 TourAPI 키 · Naver API 키 · Kakao 로그인 키 ([external-apis](docs/conventions/external-apis.md) · [auth-security](docs/conventions/auth-security.md))

## 설치 및 설정

### 백엔드 (`backend/`)

```bash
cd backend
uv sync                # 의존성 설치
uv sync --group dev    # 개발 의존성 포함
```

### 프론트엔드 (`frontend/`)

```bash
cd frontend
flutter pub get
```

- **Flutter SDK 미설치 환경**: `frontend/Dockerfile`·`frontend/docker-compose.yml`로 컨테이너에서 대신 실행할 수 있습니다.
  ```bash
  cd frontend
  docker compose run --rm frontend flutter pub get
  ```

### 환경 변수 설정

백엔드는 pydantic-settings로 `.env`에서 설정을 읽습니다([backend.md](docs/conventions/backend.md)). 운영 시크릿·API 키는 GCP Secret Manager로 관리합니다([auth-security.md](docs/conventions/auth-security.md)).

```bash
# 핵심 인프라
APP_ENV=local       # local/test/dev/prod
DATABASE_URL=        # PostgreSQL 접속 URL
LOG_LEVEL=           # 선택: DEBUG/INFO/WARNING/ERROR/CRITICAL (미설정 시 APP_ENV 기준)

# 외부 API 키
TOUR_API_KEY=        # 한국관광공사 TourAPI
NAVER_API_KEY=       # Naver 지도/지역 API

# 인증
JWT_SECRET_KEY=      # JWT(Access/Refresh) 서명 키
KAKAO_REST_API_KEY=  # Kakao REST API 키
KAKAO_REDIRECT_URI=  # Kakao authorization code 교환용 redirect URI
KAKAO_APP_ID=        # Kakao access token 발급 앱 검증용 숫자 ID
KAKAO_TOKEN_INFO_URL= # Kakao access token 검증 URL
KAKAO_CLIENT_SECRET= # client secret 활성화 시 authorization code 교환용

# 업로드 (퀘스트 인증 사진)
GCS_UPLOAD_BUCKET=   # 설정 시 GCS 사용(운영), 미설정 시 로컬 디스크(개발·테스트)
```

## 실행 방법

### 백엔드

```bash
docker compose up      # PostgreSQL + FastAPI(Uvicorn) 로컬 구동
```

- **용도**: FastAPI 백엔드 API 서버. 로컬은 Docker Compose로 PostgreSQL과 함께 구동합니다([infra-deploy.md](docs/conventions/infra-deploy.md)).

### 프론트엔드

```bash
cd frontend
flutter run                 # 연결된 기기/시뮬레이터
flutter run -d chrome       # 웹(빠른 확인용)
```

- **용도**: 다채로울지도 앱 구동. iOS/Android 실행은 각 플랫폼 툴체인(Xcode/Android SDK) 필요. 빠른 확인은 웹(Chrome)으로 가능.
- **Flutter SDK 미설치 환경(Docker)**: iOS/Android 툴체인 없이 웹 빌드·테스트만 필요할 때 사용합니다.
  ```bash
  cd frontend
  docker compose run --rm frontend flutter analyze
  docker compose run --rm frontend flutter test
  docker compose run --rm frontend flutter build web
  docker compose run --rm --service-ports frontend flutter run -d web-server --web-hostname=0.0.0.0 --web-port=5000
  ```

## 프로젝트 구조

frontend(Flutter 앱) → REST API(`/api/v1`) → backend(FastAPI) → PostgreSQL · 외부 API(TourAPI·Naver·Kakao)

```text
.
├── AGENTS.md       # Codex 등 에이전트 진입점 → docs/AGENT_GUIDE.md
├── CLAUDE.md       # Claude Code 진입점 → docs/AGENT_GUIDE.md
├── README.md       # 프로젝트 개요·구조·실행 (이 문서)
├── backend/        # 백엔드 — Python (도메인 골격: core·auth·integrations·journeys·maps·quests·regions·uploads)
├── frontend/       # 프론트엔드 — Flutter 앱 (다채로울지도)
│   ├── lib/
│   │   ├── main.dart        # 진입점 (ProviderScope)
│   │   ├── app/             # MaterialApp.router·GoRouter 라우트(app_shell 탭바 포함)·테마(디자인 토큰)
│   │   ├── core/            # Dio 클라이언트(설정)·공용 위젯(ChungbukMap·토스트·배지·필터칩)
│   │   ├── data/            # 모델·정적 데이터(static/)·Repository(정적/Auth 스텁)
│   │   ├── state/           # 전역 상태(Riverpod)·진행도 Notifier
│   │   └── features/        # 화면 단위: onboarding·survey·home·travel·quests·timeline·profile
│   ├── Dockerfile / docker-compose.yml  # Flutter SDK 미설치 환경 보조용
│   └── pubspec.yaml
├── infra/          # GCP 인프라 (Terraform / IaC) — SOT: docs/conventions/infra-deploy.md
│   ├── modules/        # 재사용 모듈 (network·compute·database)
│   ├── envs/dev/       # dev 환경 (GCS 원격 상태)
│   └── scripts/        # Cloud SQL Auth Proxy 로컬 헬퍼 등
├── deploy/         # 배포 — Compute Engine용 docker-compose·env 템플릿
└── docs/           # 문서
    ├── AGENT_GUIDE.md   # AI 에이전트 공통 가이드 (작업 워크플로우·문서 동기화 규칙)
    ├── conventions/     # 팀 기술·규약 결정 (영역별 SOT)
    ├── specs/           # 기능 스펙 (진행 중·예정 기능)
    │   └── 000-frontend-app/   # 프론트엔드 앱 스펙 + prototype/(디자인 참고 원본)
    └── template/        # 문서 템플릿 (README·specs)
```

> 새 기능 스펙은 `docs/specs/{NNN}-{기능}/`에 [`docs/template/specs/`](docs/template/specs/) 템플릿을 복사해 작성합니다. 자세한 규칙은 [docs/AGENT_GUIDE.md](docs/AGENT_GUIDE.md#기능-스펙-docsspecs)를 참고하세요.

## 실행 파이프라인 / 핵심 흐름

사용자가 Flutter 앱에서 퀘스트를 탐색·수행하면, 백엔드(`/api/v1`)가 DB와 한국관광공사 TourAPI를 조회해 공통 Envelope로 응답합니다. 퀘스트 완료(GPS·사진 인증)는 방문 기록으로 쌓여 지도 색칠과 여행 DNA에 반영됩니다.

```mermaid
flowchart TD
    A["사용자 (Flutter 앱)"] --> B["FastAPI /api/v1 (퀘스트·인증·색칠·DNA)"]
    B --> C[("PostgreSQL — 퀘스트·지역·방문 기록")]
    B --> D["한국관광공사 TourAPI · Naver API"]
    B --> E["응답 Envelope (code/status/message/data)"]
    E --> A
```

## 주요 기능과 위치

기능을 수정할 때 **어느 폴더를 건드려야 하는지**를 정리합니다. 프론트엔드 화면은 1차 구현(최소 버전) 상태이며, 남은 항목은 [docs/specs/000-frontend-app/implementation.md](docs/specs/000-frontend-app/implementation.md)를 참고하세요.

| 기능 | 설명 | 위치 |
|------|------|------|
| **온보딩·여행 DNA** | 스플래시·회원가입·초기 설문·DNA 결과 | `frontend/lib/features/onboarding/`, `frontend/lib/features/survey/` |
| **홈 지도(색칠)** | 충북 11개 시·군 색칠 지도·통계 | `frontend/lib/features/home/`, 지도 위젯 `frontend/lib/core/widgets/chungbuk_map.dart` |
| **여행 목록** | 진행중/지난 여행(지역 단위) 목록 | `frontend/lib/features/travel/` |
| **퀘스트·인증** | 지역별·상세·인증(사진/GPS/OX퀴즈), 유형별 전체 목록(보조) | `frontend/lib/features/quests/` |
| **타임라인·프로필·공유** | 완료 기록·마이·내정보수정·공유 카드 | `frontend/lib/features/timeline/`, `frontend/lib/features/profile/` |
| **도메인 데이터·상태** | 지역·퀘스트·DNA·설문 정적 데이터, 전역 상태 | `frontend/lib/data/`, `frontend/lib/state/` |
| **인증·회원(Auth/Member)** | Kakao 앱 소유권 검증·JWT·프로필/동의·즉시 익명화 탈퇴 | `backend/app/auth/` · 스펙 [docs/specs/035-kakao-auth-integration/](docs/specs/035-kakao-auth-integration/) |
| **여행 DNA(Travel DNA)** | 여행 성향 질문·선택지 조회, 답변 제출 및 DNA 판정 | `backend/app/trip_dna/` · 스펙 [docs/specs/010-travel-dna/](docs/specs/010-travel-dna/) |
| **퀘스트(Quest)** | 충북 시·군 관광 퀘스트 목록·상세·카테고리 조회 | `backend/app/quests/` · 스펙 [docs/specs/000-quest/](docs/specs/000-quest/) |
| **시·군(regions)** | 충북 11개 시·군 마스터·시드 | `backend/app/regions/` |
| **지도(maps)** | 내 지도 조회 (`GET /users/me/map`) | `backend/app/maps/` |
| **여정·퀘스트 인증(Journey)** | 여정 생성·관리, DNA 추천, 퀘스트 인증(GPS·사진·퀴즈)·완료 | `backend/app/journeys/`, `backend/app/quests/`, `backend/app/uploads/` · 스펙 [docs/specs/010-journey/](docs/specs/010-journey/) |
| **DB/데이터 모델 기반** | 여행 DNA 설문·퀘스트 진행·지도 진행·타임라인 기록을 위한 백엔드 데이터 모델 | `backend/app/auth/`, `backend/app/quests/`, `backend/app/progress/`, `backend/app/timeline/`, `backend/app/trip_dna/`, `backend/alembic/` · 스펙 [docs/specs/015-database-migration/](docs/specs/015-database-migration/) |
| **백엔드 공통 로깅** | JSON 앱 로그, 요청 메타데이터 로깅, request id 전파 | `backend/app/core/` · 스펙 [docs/specs/020-backend-logging/](docs/specs/020-backend-logging/) |

> 위 표는 기능이 **어디 있는지**를 가리킵니다. 개별 기능의 **상세 설명**은 이 README에 중복해 적지 않고, 해당 기능 스펙의 `description.md`를 단일 출처(SOT)로 둡니다. 지도 색칠·공유 등은 별도 도메인으로 진행 예정이며, 스펙이 만들어지면 이 표에 추가합니다.

## 패키지 의존성

> 버전은 `backend/`·`frontend/` 의존성 파일(`pyproject.toml`·lock / `pubspec.yaml`·lock) 확정 시 채웁니다. 스택 결정의 단일 출처는 [docs/conventions/](docs/conventions/)입니다.

### 백엔드 주요 의존성

| 패키지 | 버전 | 설명 |
| ------ | ---- | ---- |
| `fastapi` | 미정 | 웹 프레임워크 |
| `sqlalchemy` | 2.0 | ORM |
| `alembic` | 미정 | DB 마이그레이션 |
| `pydantic-settings` | 미정 | 설정·환경변수 |
| `uvicorn` | 미정 | ASGI 앱 서버 |
| `pyjwt` | 미정 | JWT 생성·검증 |
| `google-cloud-storage` | 미정 | 인증 사진 GCS 업로드 |

### 프론트엔드 주요 의존성

> 스택 결정의 SOT는 [docs/conventions/frontend.md](docs/conventions/frontend.md).

| 패키지 | 버전 | 설명 |
| ------ | ---- | ---- |
| `go_router` | `^17.3.0` | 라우팅 |
| `flutter_riverpod` | `^3.3.2` | 상태관리(전역·서버) |
| `flutter_localizations` | Flutter SDK | Material 위젯 한국어화(날짜 피커 등) |
| `dio` | `^5.9.2` | HTTP 클라이언트(현재 설정만) |
| `flutter_form_builder` · `form_builder_validators` | `^10.3.0` · `^11.3.0` | 폼 |
| `flutter_secure_storage` | `^10.3.1` | 토큰 저장(인증 연동 시) |

## 코드 스타일

### 백엔드 (Python)

```bash
uv run ruff format    # 포맷
uv run ruff check     # 린트
uv run pyright        # 타입 체크
```

설정은 백엔드 설정 파일과 루트 `.pre-commit-config.yaml`에 있습니다. 커밋 전 pre-commit이 Ruff·Pyright를 자동 검사합니다([code-quality.md](docs/conventions/code-quality.md)).

### 프론트엔드 (Flutter/Dart)

```bash
cd frontend
dart format .
flutter analyze
```

규칙 SOT: [docs/conventions/code-quality.md](docs/conventions/code-quality.md). 폰트는 Pretendard(번들), 디자인 토큰은 `lib/app/theme.dart`의 `AppColors`.

### 자주 쓰는 라이브러리·패턴

- **백엔드**: async/await 전면 적용, 응답 Envelope(`code/status/message/data`), UUID v7 PK, Soft Delete, 구조화 JSON 로깅 — 상세는 [backend.md](docs/conventions/backend.md) · [database.md](docs/conventions/database.md) · [api-design.md](docs/conventions/api-design.md) · [logging-monitoring.md](docs/conventions/logging-monitoring.md)
- **프론트엔드**: Riverpod(상태)·Dio(통신)·GoRouter(라우팅), 지도는 이미지 기반 색칠 — [frontend.md](docs/conventions/frontend.md)

## 유지 관리 사항

### 보안

- 시크릿·API 키는 코드/깃에 두지 않고 GCP Secret Manager로 관리하며, 로컬은 `.env`로 주입합니다. 클라이언트 토큰은 `flutter_secure_storage`에 저장하고, 인증은 Kakao + JWT(Access/Refresh), CORS는 허용 도메인 화이트리스트로 제한합니다. 상세는 [auth-security.md](docs/conventions/auth-security.md).

### 의존성 업데이트

```bash
uv lock --upgrade      # 백엔드 (uv)
flutter pub upgrade    # 프론트엔드 (pub)
```
