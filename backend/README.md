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
# .env의 KAKAO_APP_ID에 Kakao Developers 앱의 숫자 앱 ID 입력

# 3. 로컬 DB (PostgreSQL) 기동
docker compose up -d --wait db

# 4. 마이그레이션 적용
uv run alembic upgrade head

# 5. 마스터 시드 (충북 11개 시·군)
uv run python -m app.regions.seed

# 6. 개발 서버
uv run uvicorn app.main:app --reload --no-access-log
```

- API 문서(Swagger): `http://localhost:8000/docs`
- 전체 스택(API + DB)을 컨테이너로: `docker compose up --build`

## 환경 변수

`.env.example`를 복사해 `.env`로 사용한다. 키는 운영에서 GCP Secret Manager로 관리한다([auth-security.md](../docs/conventions/auth-security.md)).
`KAKAO_APP_ID`는 비밀이 아니지만 모든 환경에서 필요한 양의 정수 설정이다.

| 변수 | 설명 |
|------|------|
| `APP_ENV` | 실행 환경 (`local`, `test`, `dev`, `prod`) |
| `DATABASE_URL` | PostgreSQL 비동기 DSN (`postgresql+asyncpg://...`) |
| `LOG_LEVEL` | 선택 로그 레벨 override (`DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`) |
| `TOUR_API_KEY` | 한국관광공사 TourAPI 키 (미발급 시 적재는 빈 결과) |
| `TOUR_API_BASE_URL` | TourAPI base URL (기본: KorService2) |
| `JWT_SECRET_KEY` | Access JWT 서명과 refresh token hash에 사용하는 secret. `local/test` 외 환경에서는 필수이며 기본값 사용 시 앱이 시작되지 않는다. |
| `ACCESS_TOKEN_TTL_MINUTES` | Access token TTL (기본 15분) |
| `REFRESH_TOKEN_TTL_DAYS` | Refresh token TTL (기본 14일) |
| `KAKAO_APP_ID` | Kakao token info의 `app_id`와 비교할 양의 정수 앱 ID |
| `KAKAO_REST_API_KEY` | Kakao REST API 키 |
| `KAKAO_REDIRECT_URI` | Kakao authorization code 교환 시 사용하는 redirect URI. 카카오 인가 요청에 사용한 값과 같아야 한다. |
| `KAKAO_TOKEN_INFO_URL` | Kakao access token 검증 URL (기본: `https://kapi.kakao.com/v1/user/access_token_info`) |
| `KAKAO_CLIENT_SECRET` | Kakao client secret을 활성화한 경우 authorization code 교환에 사용 |
| `GCS_UPLOAD_BUCKET` | 인증 사진 업로드용 GCS 버킷 (미설정 시 로컬 디스크로 저장) |
| `UPLOAD_DIR` | 버킷 미설정 시 로컬 저장 경로 (기본: `./uploads`) |
| `MAX_UPLOAD_SIZE_MB` | 인증 사진 최대 크기 (기본 10MB) |

## 구조

```text
backend/
├── app/
│   ├── main.py              # FastAPI 진입점·라우터 등록
│   ├── core/                # config·database·base(모델 믹스인)·response(Envelope)·exceptions·enums·logging
│   ├── auth/                # Kakao 인증·JWT·온보딩·즉시 익명화 탈퇴
│   ├── regions/             # 시·군 마스터 (모델·스키마·repository·service·router·seed)
│   ├── quests/              # 퀘스트 조회·추천·진행/인증 (모델·스키마·repository·service·router·verification·dna)
│   ├── journeys/            # 여정 생성·관리 (모델·스키마·repository·service·router)
│   ├── uploads/             # 인증 사진 업로드 (router·storage: GCS/로컬)
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
| GET | `/api/v1/quests/recommended` | DNA 기반 추천 퀘스트 (보호) |
| GET | `/api/v1/quests/{quest_id}` | 퀘스트 상세 |
| POST | `/api/v1/quests/{quest_id}/start` | 퀘스트 시작(진행 생성, 보호) |
| POST | `/api/v1/quests/{quest_id}/verify` | 퀘스트 인증(GPS·사진·퀴즈, 보호) |
| GET | `/api/v1/users/me/progress` | 내 진행/완료 목록 (보호) |
| POST | `/api/v1/journeys` | 여정 생성 (보호) |
| GET | `/api/v1/journeys` | 내 여정 목록 (보호) |
| GET | `/api/v1/journeys/{journey_id}` | 여정 상세·진행률 (보호) |
| POST | `/api/v1/journeys/{journey_id}/quests` | 여정에 퀘스트 추가 (보호) |
| DELETE | `/api/v1/journeys/{journey_id}/quests/{quest_id}` | 여정에서 퀘스트 제거 (보호) |
| POST | `/api/v1/uploads/photo` | 인증 사진 업로드 (보호) |
| POST | `/api/v1/auth/login/social` | Kakao 로그인·자동 가입·토큰 발급 |
| POST | `/api/v1/auth/refresh` | 리프레시 토큰 교체 |
| POST | `/api/v1/auth/logout` | 로그아웃 |
| GET | `/api/v1/users/me` | 내 정보 조회 |
| PUT | `/api/v1/users/me/onboarding-profile` | 프로필·현재 버전 약관 동의 저장 |
| PATCH | `/api/v1/users/me` | 닉네임·생년월일 수정 |
| DELETE | `/api/v1/users/me` | 회원 탈퇴 |
| GET | `/api/v1/trip_dna/questions` | 여행 DNA 질문 조회 (`ProfiledUser` 필요) |
| POST | `/api/v1/trip_dna/replies` | 여행 DNA 답변 제출 (`ProfiledUser` 필요) |

응답은 공통 Envelope `{ code, status, message, data }`로 감싼다([api-design.md](../docs/conventions/api-design.md)).

## 로깅

앱 로그와 요청 로그는 stdout에 JSON 한 줄로 출력한다([logging-monitoring.md](../docs/conventions/logging-monitoring.md)).
`LOG_LEVEL`을 설정하지 않으면 `local/test`는 `DEBUG`, `dev/prod`는 `INFO`를 사용한다.

요청 로그는 `X-Request-ID`를 응답 헤더로 반환한다. 요청 body, query string, Authorization header, token, API key, secret은 로그에 남기지 않는다.

## 보호 API 사용자 단계

인증 dependency는 온보딩 완료 상태에 따라 세 단계로 나뉜다. JWT parsing과 active
user 조회는 dependency에서 끝내고, service에는 이미 식별된 사용자만 전달한다.

| Dependency | 조건 | 대표 API |
|------------|------|----------|
| `ActiveUser` | 유효한 access JWT, 탈퇴·익명화되지 않은 사용자 | 내 정보 조회, 온보딩 저장, 로그아웃, 탈퇴 |
| `ProfiledUser` | `ActiveUser` + 프로필 + 현재 필수 동의 완료 | 여행 DNA 질문·답변 |
| `CurrentUser` | `ProfiledUser` + 여행 DNA 완료 | 여행·퀘스트·지도·타임라인·공유·업로드 |

필요 단계가 부족하면 HTTP 403 `ONBOARDING_REQUIRED`를 반환한다. 단계 판정과
탈퇴 정책의 단일 출처는 [035 Kakao 통합 인증](../docs/specs/035-kakao-auth-integration/)과
[인증·보안 컨벤션](../docs/conventions/auth-security.md)이다.

```python
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import CurrentUser
from app.core.database import get_session
from app.core.response import Envelope, success

router = APIRouter(prefix="/quests", tags=["quests"])


@router.post("/{quest_id}/start")
async def start_quest(
    quest_id: str,
    current_user: CurrentUser,
    session: AsyncSession = Depends(get_session),
) -> Envelope[dict[str, str]]:
    # service에는 JWT가 아니라 식별된 사용자 정보만 전달한다.
    # await quest_service.start_quest(
    #     session,
    #     user_id=current_user.id,
    #     quest_id=quest_id,
    # )
    return success({"quest_id": quest_id, "user_id": str(current_user.id)})
```

클라이언트는 보호 API 요청에 access token을 전달한다.

```http
Authorization: Bearer <access_token>
```

`ActiveUser`는 JWT 서명, 만료 시간, token type, `sub`를 검증한 뒤 DB에서 active user를 다시 조회한다.
헤더 누락, 잘못된 token, refresh token 사용, 탈퇴/익명화 사용자는 `UNAUTHORIZED_ERROR` 또는 `TOKEN_EXPIRED_ERROR`로 응답한다.

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
