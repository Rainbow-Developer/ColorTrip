# ColorTrip Backend

FastAPI 기반 백엔드. 규약은 [docs/conventions/](../docs/conventions/), 기능 스펙은 [docs/specs/](../docs/specs/)를 단일 출처로 한다.

## 요구사항

- Python 3.13 / [uv](https://docs.astral.sh/uv/)
- Docker (로컬 PostgreSQL)

## 실행

```bash
cd backend

# 1. 의존성
uv sync

# 2. 로컬 환경 변수
cp .env.example .env

# 3. 로컬 DB (PostgreSQL) 기동
docker compose up -d --wait db

# 4. 마이그레이션 적용
uv run alembic upgrade head

# 5. 마스터 시드 (충북 11개 시·군)
uv run python -m app.regions.seed

# 6. 개발 서버
uv run uvicorn app.main:app --reload
```

- API 문서(Swagger): `http://localhost:8000/docs`
- 전체 스택(API + DB)을 컨테이너로: `docker compose up --build`

## 환경 변수

`.env.example`를 복사해 `.env`로 사용한다. 키는 운영에서 GCP Secret Manager로 관리한다([auth-security.md](../docs/conventions/auth-security.md)).

| 변수 | 설명 |
|------|------|
| `APP_ENV` | 실행 환경 (`local`, `test`, `dev`, `prod`) |
| `DATABASE_URL` | PostgreSQL 비동기 DSN (`postgresql+asyncpg://...`) |
| `TOUR_API_KEY` | 한국관광공사 TourAPI 키 (미발급 시 적재는 빈 결과) |
| `TOUR_API_BASE_URL` | TourAPI base URL (기본: KorService2) |
| `JWT_SECRET_KEY` | Access JWT 서명과 refresh token hash에 사용하는 secret. `local/test` 외 환경에서는 필수이며 기본값 사용 시 앱이 시작되지 않는다. |
| `ACCESS_TOKEN_TTL_MINUTES` | Access token TTL (기본 15분) |
| `REFRESH_TOKEN_TTL_DAYS` | Refresh token TTL (기본 14일) |
| `KAKAO_REST_API_KEY` | Kakao REST API 키 |
| `KAKAO_REDIRECT_URI` | Kakao authorization code callback URI |
| `ENABLE_DEV_AUTH_ROUTES` | 로컬 Kakao OAuth 검증 route 노출 여부 |

## 구조

```text
backend/
├── app/
│   ├── main.py              # FastAPI 진입점·라우터 등록
│   ├── core/                # config·database·base(모델 믹스인)·response(Envelope)·exceptions·enums
│   ├── auth/                # Kakao 인증·JWT·회원 탈퇴/복구
│   ├── regions/             # 시·군 마스터 (모델·스키마·repository·service·router·seed)
│   ├── quests/              # 퀘스트 (모델·스키마·repository·service·router)
│   └── integrations/tour_api/  # 한국관광공사 TourAPI 클라이언트·적재 로더
├── alembic/                 # 마이그레이션
├── docker-compose.yml       # 로컬 PostgreSQL + API
└── Dockerfile
```

## API (v1)

| 메서드 | 경로 | 설명 |
|--------|------|------|
| GET | `/api/v1/regions` | 충북 시·군 목록 |
| GET | `/api/v1/quests` | 퀘스트 목록 (`region_id`·`category`·`page`·`size`) |
| GET | `/api/v1/quests/{quest_id}` | 퀘스트 상세 |
| POST | `/api/v1/auth-tokens` | Kakao 로그인·자동 가입·토큰 발급 |
| POST | `/api/v1/auth-token-renewals` | Refresh token rotation |
| DELETE | `/api/v1/auth-tokens/current` | 로그아웃 |
| GET | `/api/v1/users/me` | 내 정보 조회 |
| DELETE | `/api/v1/users/me` | 회원 탈퇴 |

응답은 공통 Envelope `{ code, status, message, data }`로 감싼다([api-design.md](../docs/conventions/api-design.md)).

## 테스트

Auth/Member 테스트는 PostgreSQL을 사용한다.
테스트 fixture는 Alembic `upgrade head`로 스키마를 만든 뒤 API 테스트를 실행한다.

```bash
docker compose -f docker-compose.test.yml up -d
uv run pytest -q
```

## 코드 품질

```bash
uv run ruff format .
uv run ruff check .
uv run pyright
```
