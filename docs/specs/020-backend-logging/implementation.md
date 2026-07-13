# [구현 수준] 백엔드 공통 로깅 시스템

| 항목 | 내용 |
|------|------|
| 상태 | 완료 |
| 최종 업데이트 | 2026-07-13 |

## 구현 규모 / 단위 분할

- **규모 판단**: 한 번에 구현 — 새 의존성이나 인프라 변경 없이 `app/core`, 앱 진입점, 런타임 설정, 테스트, 문서 갱신으로 닫히는 작은 백엔드 공통 기능이다.
- **구현 단위**:
  - [x] 1) 스펙과 컨벤션 문서 정리.
  - [x] 2) 설정과 공통 로깅 모듈 구현.
  - [x] 3) 요청 로깅 미들웨어와 런타임 설정 연결.
  - [x] 4) 테스트와 품질 게이트 검증.

## 구현된 항목

- `docs/specs/020-backend-logging/` 스펙 작성.
- `backend/app/core/logging.py`에 JSON formatter, request id context, redaction filter, 순수 ASGI 요청 로깅 미들웨어 등록 함수를 추가했다.
- 요청 로그는 스트리밍을 포함한 응답 전송 완료 후 한 번 기록하고, 5xx와 처리 중 예외는 `ERROR`로 분류한다.
- 문자열 메시지뿐 아니라 구조화 extra, 중첩 객체, exception traceback, stack 정보에도 키 인식 redaction을 적용한다.
- `backend/app/core/config.py`에 `LOG_LEVEL` 설정과 검증을 추가했다.
- 공통 handler에 최종 로그 레벨을 적용해 명시적 레벨을 가진 하위 logger에도 동일한 기준을 강제한다.
- `backend/app/main.py`에서 앱 시작 시 로깅 설정과 요청 로깅 미들웨어를 등록한다.
- 처리 중 예외는 로깅 후 재전파하고, 공통 예외 핸들러가 `INTERNAL_ERROR` Envelope와 `X-Request-ID`를 반환한다.
- `backend/Dockerfile`, `backend/docker-compose.yml`, `backend/.env.example`, `deploy/deploy.sh`에 런타임 설정을 반영했다.
- `backend/tests/test_logging.py`로 formatter, 재귀 redaction, request id, 실제 앱 연결, 스트리밍 완료 시점, 5xx 및 예외 로그를 검증한다.

## 미구현 / 남은 항목

- 없음.

## 알려진 한계 / TODO

- Cloud Logging 수집 인프라는 이번 범위가 아니다. Compute Engine Ops Agent 또는 컨테이너 로그 수집 구성은 별도 인프라 작업으로 진행한다.
- 분산 tracing은 이번 범위가 아니다. 프록시/로드밸런서 도입 시 trace header 연동을 재검토한다.

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-07-12 | 백엔드 공통 로깅 시스템 스펙 최초 작성 |
| 2026-07-12 | 백엔드 공통 JSON 로깅, 요청 로깅 미들웨어, 테스트 구현 |
| 2026-07-13 | redaction 보강, 순수 ASGI 미들웨어 전환, 예외 흐름·로그 레벨·스트리밍 회귀 테스트 추가 |
