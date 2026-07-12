# [설명] 백엔드 공통 로깅 시스템

## 개요

백엔드 공통 로깅 시스템은 ColorTrip FastAPI 앱의 로그를 구조화 JSON 형식으로 stdout에 출력하는 기반 기능이다. 앱 내부 로그와 요청 로그가 같은 formatter를 사용하므로, 로컬 Docker 로그와 운영 컨테이너 로그에서 동일한 필드 구조로 확인할 수 있다.

요청마다 `request_id`를 부여하고 응답 헤더 `X-Request-ID`로 반환해, 클라이언트 오류 보고와 서버 로그를 연결할 수 있게 한다.

## 동작 방식

```text
앱 시작
  -> settings.LOG_LEVEL 해석
  -> root/app/uvicorn logger에 JSON formatter 적용
  -> FastAPI 요청 로깅 미들웨어 등록

요청 처리
  -> X-Request-ID 검증 또는 생성
  -> ContextVar에 request_id 저장
  -> 라우터/정적 파일 핸들러 실행
  -> status_code, duration_ms, method, path, client_ip 로그 출력
  -> 응답 헤더 X-Request-ID 반환
```

요청 로그는 body, query string, Authorization header를 기록하지 않는다. 앱 내부 로그 메시지에 토큰이나 시크릿 형태의 값이 섞인 경우 redaction filter가 대표적인 민감 패턴을 마스킹한다.

## 주요 구성 요소 / 위치

| 구성 요소 | 역할 | 위치 |
|-----------|------|------|
| `setup_logging` | 앱 시작 시 JSON formatter와 로그 레벨 적용 | `backend/app/core/logging.py` |
| `JsonLogFormatter` | `logging.LogRecord`를 JSON 한 줄로 직렬화 | `backend/app/core/logging.py` |
| `SensitiveDataFilter` | 토큰, API 키, secret류 문자열 마스킹 | `backend/app/core/logging.py` |
| `register_request_logging` | FastAPI 요청 로깅 미들웨어 등록 | `backend/app/core/logging.py` |
| `request_id` context | 요청 단위 상관관계 ID 저장 | `backend/app/core/logging.py` |
| `Settings.log_level` | 환경별 기본값과 override 설정 | `backend/app/core/config.py` |
| 앱 진입점 | 로깅 설정과 미들웨어 등록 | `backend/app/main.py` |

## 설정 / 사용법

환경변수 `LOG_LEVEL`은 선택값이다. 미설정 시 `APP_ENV`에 따라 기본값을 사용한다.

| 환경 | 기본 로그 레벨 |
|------|---------------|
| `local` | `DEBUG` |
| `test` | `DEBUG` |
| `dev` | `INFO` |
| `prod` | `INFO` |

지원 로그 레벨은 `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`이다.

```bash
APP_ENV=local
LOG_LEVEL=DEBUG
uv run uvicorn app.main:app --reload --no-access-log
```

## 예시

요청 로그 예시:

```json
{"time":"2026-07-12T12:34:56.789+09:00","severity":"INFO","message":"request completed","logger":"app.request","request_id":"7d8f9b2c4e7a4b24a2d3a1f0e9c8b7a6","method":"GET","path":"/health","status_code":200,"duration_ms":3.42,"client_ip":"127.0.0.1"}
```

앱 내부 로그 예시:

```python
import logging

logger = logging.getLogger(__name__)
logger.info("quest loaded")
```

## 관련 문서

- [plan.md](plan.md) · [implementation.md](implementation.md)
- [로깅 & 모니터링 컨벤션](../../conventions/logging-monitoring.md)
- [백엔드 컨벤션](../../conventions/backend.md)
