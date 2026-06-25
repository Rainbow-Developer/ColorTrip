# [컨벤션] 백엔드 스택

> **범위**: 백엔드 프레임워크·언어·의존성·ORM·마이그레이션·비동기·설정·앱 서버
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

## 규칙 / 적용

- async/await를 전면 적용한다. DB 접근과 외부 호출은 모두 비동기로 통일한다.
- 설정과 환경변수는 pydantic-settings로 일원화하고 `.env`로 주입한다.
- 백그라운드 작업은 FastAPI BackgroundTasks로 처리한다.
- 앱 서버는 로컬·운영 모두 Uvicorn으로 구동한다.

## 관련 문서

- [데이터베이스 & 모델링](./database.md)
- [인프라 & 배포](./infra-deploy.md)
