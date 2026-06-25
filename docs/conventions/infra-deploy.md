# [컨벤션] 인프라 & 배포 (CI/CD)

> **범위**: 로컬 환경·운영 컴퓨팅·운영 DB·환경 분리·CI/CD·레지스트리·IaC·도메인
> **변경 시**: 이 문서를 단일 출처로 갱신합니다 ([AGENT_GUIDE 문서 동기화](../AGENT_GUIDE.md#문서-동기화-필수) 참고).

## 결정 사항

| 항목 | 결정 | 비고 |
|------|------|------|
| 로컬 개발 환경 | Docker Compose (PostgreSQL + FastAPI) | |
| 로컬 API ↔ 실기기(앱) 연결 | 같은 Wi-Fi LAN IP | |
| GCP 컴퓨팅(운영) | 단일 Compute Engine 인스턴스 | |
| 운영 DB | Cloud SQL (PostgreSQL) | |
| 환경 분리 | dev / prod (2환경) | |
| CI/CD | GitHub Actions (브랜치별 자동 배포) | |
| 컨테이너 레지스트리 | Artifact Registry | |
| 인프라 코드화(IaC) | 콘솔에서 수동 설정 (IaC 미적용) | |
| 도메인 & HTTPS | 도메인 구매 + SSL | |

## 규칙 / 적용

- 로컬은 Docker Compose로 PostgreSQL과 FastAPI를 함께 구동한다.
- 실기기(앱)는 로컬 API에 같은 Wi-Fi LAN IP로 접속한다.
- 운영은 단일 Compute Engine 인스턴스와 Cloud SQL (PostgreSQL)로 구성한다.
- 환경은 dev / prod 2환경으로 분리한다.
- CI/CD는 GitHub Actions로 브랜치별 자동 배포한다.
- 컨테이너 이미지는 Artifact Registry에 보관한다.
- 인프라는 콘솔에서 수동 설정하며 IaC는 적용하지 않는다.
- 도메인은 구매하고 SSL을 적용해 HTTPS를 제공한다.

## 관련 문서

- [SCM & 협업](./scm-collaboration.md) — 브랜치 전략
- [로깅 & 모니터링](./logging-monitoring.md) — 로그 수집
