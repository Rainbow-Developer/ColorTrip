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

# 2. 로컬 DB (PostgreSQL) 기동
docker compose up -d --wait db

# 3. 마이그레이션 적용
uv run alembic upgrade head

# 4. 마스터 시드 (충북 11개 시·군)
uv run python -m app.regions.seed

# 5. 개발 서버
uv run uvicorn app.main:app --reload
```

- API 문서(Swagger): `http://localhost:8000/docs`
- 전체 스택(API + DB)을 컨테이너로: `docker compose up --build`

## 환경 변수

`.env.example`를 복사해 `.env`로 사용한다. 키는 운영에서 GCP Secret Manager로 관리한다([auth-security.md](../docs/conventions/auth-security.md)).

| 변수 | 설명 |
|------|------|
| `DATABASE_URL` | PostgreSQL 비동기 DSN (`postgresql+asyncpg://...`) |
| `TOUR_API_KEY` | 한국관광공사 TourAPI 키 (미발급 시 적재는 빈 결과) |
| `TOUR_API_BASE_URL` | TourAPI base URL (기본: KorService2) |

## 구조

```text
backend/
├── app/
│   ├── main.py              # FastAPI 진입점·라우터 등록
│   ├── core/                # config·database·base(모델 믹스인)·response(Envelope)·exceptions·enums
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

응답은 공통 Envelope `{ code, status, message, data }`로 감싼다([api-design.md](../docs/conventions/api-design.md)).

## 코드 품질

```bash
uv run ruff format .
uv run ruff check .
uv run pyright
```
