# [컨벤션] 로깅 & 모니터링

> **범위**: 로그 형식·수집·에러 트래킹·요청 로깅·모니터링/알림·로그 레벨
> **변경 시**: 이 문서를 단일 출처로 갱신합니다 ([AGENT_GUIDE 문서 동기화](../AGENT_GUIDE.md#문서-동기화-필수) 참고).

## 결정 사항

| 항목 | 결정 | 비고 |
|------|------|------|
| 앱 로그 형식 | 구조화 JSON 로깅 | |
| 로그 수집 | GCP Cloud Logging | |
| 에러 트래킹 | 초기엔 안 함 | |
| 요청 로깅 | 미들웨어로 전 요청 로깅 | |
| 모니터링 / 알림 | Cloud Monitoring + Slack 알림 | |
| 로그 레벨 운영 기준 | DEBUG(개발) / INFO(운영) | |
| 로그 레벨 설정 | `LOG_LEVEL` 선택 override | 미설정 시 `APP_ENV` 기준 |
| 요청 식별자 | `X-Request-ID` 수용·생성 | 응답 헤더로 반환 |

## 규칙 / 적용

- 앱 로그는 구조화 JSON 형식으로 출력한다.
- 앱은 stdout에 JSON 로그를 출력하고, 운영 로그 수집은 GCP Cloud Logging으로 연결한다.
- 에러 트래킹은 초기에는 도입하지 않는다.
- 요청은 미들웨어로 전수 로깅한다.
- 운영 알림은 Cloud Monitoring에서 감지해 Slack으로 보낸다.
- 로그 레벨은 개발 환경 DEBUG, 운영 환경 INFO로 운영한다.
- `LOG_LEVEL`이 설정되면 환경별 기본 로그 레벨을 덮어쓴다. 허용 값은 `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`이다.
- 공통 handler에도 최종 로그 레벨을 적용해 명시적 레벨을 가진 하위 logger가 설정을 우회하지 못하게 한다.
- 요청 로그는 `time`, `severity`, `message`, `logger`, `request_id`, `method`, `path`, `status_code`, `duration_ms`, `client_ip`를 기본 필드로 한다.
- 요청 duration은 스트리밍을 포함한 응답 body 전송이 완료될 때까지 측정한다.
- 정상적인 2xx~4xx 응답은 `INFO`, 5xx 응답과 처리 중 예외는 `ERROR`로 기록한다.
- 처리 중 예외는 요청 로그를 남긴 뒤 재전파해 기존 FastAPI 예외 처리 흐름을 보존한다.
- 요청 body, query string, Authorization header, access/refresh token, API key, secret, password는 로그에 남기지 않는다. 메시지, 구조화 필드, 중첩 객체, exception traceback, stack 정보에도 같은 redaction 규칙을 적용한다.

## 관련 문서

- [인프라 & 배포 (CI/CD)](./infra-deploy.md)
