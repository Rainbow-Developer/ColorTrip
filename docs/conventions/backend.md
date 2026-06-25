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
| 도메인 모듈 내부 구성 | 미정 | router·service·model·schema 분리 방식 추후 결정 |

## 규칙 / 적용

- async/await를 전면 적용한다. DB 접근과 외부 호출은 모두 비동기로 통일한다.
- 설정과 환경변수는 pydantic-settings로 일원화하고 `.env`로 주입한다.
- 백그라운드 작업은 FastAPI BackgroundTasks로 처리한다.
- 앱 서버는 로컬·운영 모두 Uvicorn으로 구동한다.
- 애플리케이션 코드는 `app/` 아래에 두고, 비즈니스 도메인은 도메인별 패키지로 분리한다(`app/quests/`, `app/regions/` 등).
- 영역 공통 코드(설정 등)는 `app/core/`에, 외부 API 연동은 `app/integrations/{서비스}/`에 서비스별로 둔다. 연동 대상·정책은 [외부 API & 데이터 연동](./external-apis.md)을 따른다.
- DB 마이그레이션은 `alembic/`에서 관리하고 리비전 파일은 `alembic/versions/`에 둔다.
- 실제 전체 디렉토리 트리는 [README의 프로젝트 구조](../../README.md#프로젝트-구조)가 단일 출처다. 이 문서는 구성 원칙만 정의한다.

## 관련 문서

- [데이터베이스 & 모델링](./database.md)
- [인프라 & 배포](./infra-deploy.md)
- [외부 API & 데이터 연동](./external-apis.md)
- 실제 디렉토리 트리: [README 프로젝트 구조](../../README.md#프로젝트-구조)
