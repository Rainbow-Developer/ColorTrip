# [계획] 백엔드 공통 로깅 시스템

| 항목 | 내용 |
|------|------|
| 기능명 | 백엔드 공통 로깅 시스템 |
| Spec 폴더 | `docs/specs/020-backend-logging/` |
| 영역 | backend |
| 작성자 | Backend Logging 담당 |
| 작성일 | 2026-07-12 |
| 상태 | 완료 |

## 배경 / 목적

ColorTrip 백엔드는 FastAPI, Uvicorn, Docker Compose, Compute Engine 기반으로 동작한다. 현재 컨벤션은 구조화 JSON 로깅, 요청 전수 로깅, 환경별 로그 레벨을 요구하지만 앱 코드에는 이를 일관되게 적용하는 공통 로깅 모듈이 없다.

이 작업은 `backend/app/core/`에 백엔드 공통 로깅 기반을 추가해 모든 앱 로그와 요청 로그가 같은 형식으로 stdout에 출력되도록 한다. Cloud Logging 수집 인프라는 별도 인프라 작업으로 다루고, 이번 범위는 앱이 구조화 로그를 내보내는 데 집중한다.

## 목표 (Goals)

| ID | 목표 |
|----|------|
| LOG-01 | Python 표준 `logging` 기반 JSON formatter 제공 |
| LOG-02 | `LOG_LEVEL` 설정과 환경별 기본 로그 레벨 적용 |
| LOG-03 | FastAPI 앱 전체 요청에 대한 요청/응답 메타데이터 로깅 |
| LOG-04 | `X-Request-ID` 수용/생성과 응답 헤더 전파 |
| LOG-05 | 토큰, 시크릿, API 키 등 민감정보 로그 노출 방지 |
| LOG-06 | Uvicorn access log와 앱 요청 로그 중복 방지 |
| LOG-07 | 단위/요청 테스트로 로깅 형식과 보안 정책 검증 |

## 비목표 (Non-Goals)

- `app/common` 패키지 신설.
- `structlog`, `python-json-logger`, `google-cloud-logging` 등 새 로깅 의존성 도입.
- Compute Engine Ops Agent, Terraform, Cloud Logging 수집 인프라 구현.
- Cloud Monitoring 알림, Slack 알림, Error Reporting, distributed tracing 구현.
- 프론트엔드 로깅.

## 요구사항

**기능**
- 앱 로그는 JSON 한 줄로 stdout에 출력한다.
- 요청 로그는 method, path, status_code, duration_ms, client_ip, request_id를 포함한다.
- `X-Request-ID`가 들어오면 안전한 값만 재사용하고, 없거나 부적절하면 서버가 새 값을 생성한다.
- 생성/확정된 request id는 응답 헤더 `X-Request-ID`로 반환한다.
- 기존 `logging.getLogger(__name__)` 호출 방식은 유지한다.

**비기능**
- 요청 body, query string, Authorization header, access/refresh token, service key, password, secret은 로그에 남기지 않는다.
- 민감정보 마스킹은 메시지뿐 아니라 구조화 extra, 중첩 객체, 예외 traceback, stack 정보에도 적용한다.
- `local`, `test` 기본 로그 레벨은 `DEBUG`, `dev`, `prod` 기본 로그 레벨은 `INFO`로 한다.
- `LOG_LEVEL`이 설정되면 기본값을 덮어쓴다.
- 잘못된 `LOG_LEVEL` 값은 앱 시작 시 설정 검증에서 실패한다.
- 최종 로그 레벨은 명시적인 레벨을 가진 하위 logger에도 공통 handler에서 일관되게 적용한다.
- Uvicorn access log는 앱 요청 로그와 중복되지 않게 끈다.

## 설계 개요 / 접근 방식

```text
HTTP request
  |
  v
FastAPI pure ASGI middleware
  |
  +-- validate or create X-Request-ID
  +-- set request_id ContextVar
  +-- call route/static/streaming handler
  +-- return X-Request-ID in response start
  +-- wait until the response body is complete
  +-- log request metadata as JSON once
  |
  v
stdout JSON logs -> container logs -> infrastructure collection layer
```

- `backend/app/core/logging.py`는 formatter, filter, request context, middleware 등록 함수를 한 곳에 둔다.
- Cloud Logging이 이해하기 쉬운 필드 이름(`time`, `severity`, `message`, `logger`)을 사용한다.
- 요청 로그는 별도 logger 이름 `app.request`로 남겨 앱 내부 로그와 구분한다.
- 요청 duration은 응답 body 전송이 완료될 때까지 측정한다.
- 5xx 응답과 처리 중 예외는 요청 메타데이터를 `ERROR`로 남긴다.
- 처리 중 예외는 로깅 후 재전파해 기존 FastAPI 예외 핸들러와 응답 Envelope 흐름을 유지한다.

## 의사결정 (함께 논의 · 근거 필수)

| 결정할 항목 | 선택지 | 결정 / 근거 | 상태 |
|------|--------|------------|------|
| 공통 모듈 위치 | `app/core` / `app/common` | **`app/core`** — 백엔드 컨벤션에서 `app/core/`가 공통·핵심 모듈로 정의되어 있다. | 합의됨 |
| 로깅 구현 | stdlib `logging` / 외부 라이브러리 | **stdlib `logging`** — 기존 코드가 `logging.getLogger(__name__)`를 사용하고, v1 요구사항은 표준 라이브러리로 충분하다. | 합의됨 |
| 요청 로그 범위 | 메타데이터만 / query 포함 / body 포함 | **메타데이터만** — 인증/개인정보 유출 위험을 낮추고 장애 추적에 필요한 최소 정보는 확보한다. | 합의됨 |
| Cloud Logging 처리 | 앱 JSON stdout / GCP SDK 직접 연동 / Ops Agent 포함 | **앱 JSON stdout** — 수집 인프라는 별도 레이어이며 이번 작업은 앱 출력 형식을 완성한다. | 합의됨 |
| 요청 식별자 | `X-Request-ID` 수용+생성 / 항상 생성 | **수용+생성** — 프록시나 클라이언트 추적 ID와 연결할 수 있고, 없는 요청도 추적 가능하다. | 합의됨 |

## 영향 범위

- `backend/app/core/logging.py`: 공통 로깅 모듈 추가.
- `backend/app/core/config.py`: `LOG_LEVEL` 설정 추가.
- `backend/app/main.py`: 앱 로깅 설정과 요청 로깅 미들웨어 등록.
- `backend/Dockerfile`: Uvicorn access log 중복 방지.
- `backend/docker-compose.yml`, `backend/.env.example`, `deploy/deploy.sh`: `LOG_LEVEL` 설정 반영.
- `backend/tests/test_logging.py`: 로깅 동작 테스트 추가.
- `README.md`, `backend/README.md`, `docs/conventions/logging-monitoring.md`, `docs/specs/README.md`: 문서 갱신.

## 작업 단계

- [x] `docs/specs/020-backend-logging/` 스펙 작성.
- [x] `Settings`에 `LOG_LEVEL` 설정과 검증 추가.
- [x] JSON formatter, redaction filter, request context 구현.
- [x] FastAPI 요청 로깅 미들웨어 등록.
- [x] Uvicorn access log 중복 방지 설정.
- [x] 테스트 추가.
- [x] 로깅 변경 범위 Ruff, Pyright, pytest 검증.

## 리스크 / 미해결 질문

- Compute Engine에서 Cloud Logging으로 실제 수집하려면 Ops Agent 또는 컨테이너 로그 수집 구성이 별도 작업으로 필요하다.
- 향후 프록시/로드밸런서를 도입하면 `X-Request-ID` 외에 trace header 연동을 다시 검토해야 한다.
