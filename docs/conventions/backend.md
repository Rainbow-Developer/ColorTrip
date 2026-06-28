# [컨벤션] 백엔드 스택

> **범위**: 백엔드 프레임워크·언어·의존성·ORM·마이그레이션·비동기·설정·앱 서버·코드 구성(디렉토리 구조)
> **변경 시**: 이 문서를 단일 출처로 갱신합니다 ([AGENT_GUIDE 문서 동기화](../AGENT_GUIDE.md#문서-동기화-필수) 참고).

## 결정 사항

| 항목 | 결정 | 비고 |
|------|------|------|
| 프레임워크 | FastAPI | |
| Python 버전 | 3.13 | |
| 패키지 / 의존성 관리 | uv | |
| ORM | SQLAlchemy 2.0 | |
| DB 마이그레이션 | Alembic | |
| 비동기 처리 | async/await 전면 적용 | DB 접근·외부 호출은 비동기로 통일 |
| 설정 / 환경변수 | pydantic-settings + .env | |
| 백그라운드 작업 | FastAPI BackgroundTasks | |
| 앱 서버(로컬·운영 구동) | Uvicorn | |
| 로컬 구동 스택(확정) | Docker · PostgreSQL · FastAPI | |
| 애플리케이션 코드 루트 | `app/` | |
| 코드 구성 단위 | 도메인별 패키지 | 도메인마다 `app/{도메인}/` (예: `quests`, `regions`) |
| 공통·핵심 모듈 | `app/core/` | 설정 등 영역 공통 코드 |
| 외부 API 연동 | `app/integrations/{서비스}/` | 예: `app/integrations/tour_api/` |
| 마이그레이션 위치 | `alembic/` (리비전은 `alembic/versions/`) | 도구는 위 Alembic |
| 도메인 모듈 내부 구성 | `models`·`schemas`·`repository`·`service`·`router` | 도메인 패키지 공통 구성 (예: `app/quests/`) |

## 규칙 / 적용

### 💡 파이썬 문법 규칙

- **타입 힌트 필수화**: 모든 함수의 입력 인자(Parameters)와 반환값(Return Types)에는 명확한 타입을 기재합니다.
  ```python
  def get_user_status(user_id: int) -> str:
      return "active"
  ```
- **비동기 함수 (`async def` vs `def`) 규칙**:
  - `I/O Bound 작업` (DB 조회, 외부 API 호출 등)은 `async def`를 선언하고 비동기 라이브러리를 사용합니다.
  - `CPU Bound / Non-I/O 작업` (단순 연산, 포맷 파싱 등)은 일반 `def`를 사용합니다.

### 📁 디렉터리 구조 및 구성 원칙

애플리케이션 코드는 `app/` 아래에 두며, 전체적인 디렉터리 구조와 역할은 다음과 같습니다.

- **`app/`**: 전체 소스 코드 진입점
  - **`app/main.py`**: FastAPI 인스턴스 생성 및 설정
  - **`app/api/`**: 엔드포인트 레이어 (버전 관리 `/v1/endpoints/` 포함)
  - **`app/core/`**: 환경 설정(`config.py`), 보안(`security.py`), DB 세션 및 연결(`database.py`)
  - **`app/models/`**: SQLAlchemy/SQLModel 데이터베이스 테이블 정의
  - **`app/schemas/`**: Pydantic DTO (입출력 데이터 유효성 검증)
  - **`app/services/`**: 순수 비즈니스 로직 처리 레이어
- **`tests/`**: Pytest 기반 유닛 테스트 디렉터리
- **도메인별 패키지 구성**: 비즈니스 도메인은 도메인별 패키지로 분리합니다 (`app/quests/`, `app/regions/` 등). 각 도메인 패키지 내부에서도 `models.py`, `schemas.py`, `repository.py`, `service.py`, `router.py`로 책임을 분리하여 작성합니다.
- **외부 API 연동**: `app/integrations/{서비스}/` 아래에 둡니다 (예: `app/integrations/tour_api/`). 연동 정책은 [외부 API & 데이터 연동](./external-apis.md)을 따릅니다.
- **DB 마이그레이션**: `alembic/`에서 관리하고 리비전 파일은 `alembic/versions/`에 둡니다.

> [!NOTE]
> 실제 전체 디렉토리 트리는 [README의 프로젝트 구조](../../README.md#프로젝트-구조)가 단일 출처(SOT)입니다. 본 문서는 구성 원칙과 책임을 정의합니다.

## 관련 문서

- [데이터베이스 & 모델링](./database.md)
- [인프라 & 배포](./infra-deploy.md)
- [외부 API & 데이터 연동](./external-apis.md)
- 실제 디렉토리 트리: [README 프로젝트 구조](../../README.md#프로젝트-구조)
