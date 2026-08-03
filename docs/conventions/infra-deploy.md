# [컨벤션] 인프라 & 배포 (CI/CD)

> **범위**: 로컬 환경·운영 컴퓨팅·운영 DB·환경 분리·CI/CD·레지스트리·IaC·도메인
> **변경 시**: 이 문서를 단일 출처로 갱신합니다 ([AGENT_GUIDE 문서 동기화](../AGENT_GUIDE.md#문서-동기화-필수) 참고).

## 결정 사항

| 항목 | 결정 | 비고 |
|------|------|------|
| 로컬 개발 환경 | Docker Compose (PostgreSQL + FastAPI) | |
| 로컬 API ↔ 앱 연결 | 실기기는 같은 Wi-Fi LAN IP, Android emulator는 `10.0.2.2` | |
| 인프라 코드화(IaC) | **Terraform** | 상태는 GCS 버킷 `colortrip-tfstate`에 원격 저장(버전 관리). 콘솔 수동 설정 금지. 코드: [`infra/`](../../infra/) |
| GCP 프로젝트 | 단일 프로젝트 `colortrip` | 리소스는 환경 접두사(`colortrip-<env>-*`)로 구분 |
| 리전 | `asia-northeast3` (서울) | |
| 환경 분리 | dev / prod (2환경) | **현재 dev부터 구축**, prod는 이후 `infra/envs/prod/` 추가로 확장 |
| GCP 컴퓨팅(운영) | 단일 Compute Engine 인스턴스 | Ubuntu 22.04 + Docker. Cloud SQL Proxy·백엔드 API 구동. Flutter 모바일 앱은 별도 빌드·배포. 기본 `e2-small` |
| 운영 DB | Cloud SQL (PostgreSQL 16) | 기본 `db-g1-small`, 단일 존(dev) |
| DB 접속 방식 | Cloud SQL Auth Proxy | 서비스 계정 IAM 인증. 공인 IP에 authorized networks를 두지 않음(직접 접속 차단). 로컬은 [`infra/scripts/db-proxy.sh`](../../infra/scripts/db-proxy.sh) |
| 시크릿 관리 | GCP Secret Manager | DB 비밀번호 등. SOT는 [auth-security](./auth-security.md) |
| 컨테이너 레지스트리 | Artifact Registry | `asia-northeast3-docker.pkg.dev/colortrip/colortrip-<env>` |
| CI/CD | GitHub Actions dev 자동 배포 | 이미지 빌드→Artifact Registry 푸시→Alembic migration→API 교체 |
| 도메인 & HTTPS | 도메인 구매 + SSL | (구축 예정) |

## 규칙 / 적용

- 로컬은 Docker Compose로 PostgreSQL과 FastAPI를 함께 구동한다.
- 실기기는 로컬 API에 같은 Wi-Fi LAN IP로 접속하고 Android emulator는 호스트를 `10.0.2.2`로 접근한다.
- **운영 인프라는 Terraform으로 관리한다**(`infra/`). 콘솔에서 수동으로 리소스를 만들지 않는다. 상태는 GCS 원격 백엔드에 둔다.
- GCP는 단일 프로젝트 `colortrip`를 쓰고, 리소스 이름에 환경 접두사(`colortrip-dev-*`)를 붙여 dev/prod가 한 프로젝트에 공존해도 충돌하지 않게 한다.
- 운영은 단일 Compute Engine 인스턴스와 Cloud SQL (PostgreSQL)로 구성한다.
- 인스턴스는 Docker로 Cloud SQL Proxy와 백엔드 API 컨테이너를 구동한다. Flutter 모바일 앱은 인스턴스에 배포하지 않는다.
- DB는 Cloud SQL Auth Proxy로만 접속한다(서비스 계정 IAM 인증). DB를 인터넷에 직접 노출하지 않는다.
- 환경은 dev / prod 2환경으로 분리하되, 현재는 dev를 먼저 구축하고 prod는 이후 추가한다.
- dev CI/CD는 GitHub Actions로 API 이미지를 만들고 Artifact Registry에 푸시한 뒤 인스턴스에 배포한다.
- 새 API 교체 전 같은 이미지로 `alembic upgrade head`를 실행하며, migration 실패 시 기존 API를 유지하고 배포를 실패 처리한다.
- 컨테이너 이미지는 Artifact Registry에 보관한다.
- 도메인은 구매하고 SSL을 적용해 HTTPS를 제공한다.

## 관련 문서

- [GCP 리소스·접근 정보](../gcp-access.md) — 실제 리소스 값(IP·서비스 계정·연결 이름)·접근 절차(팀 공유용)
- [`infra/README.md`](../../infra/README.md) — Terraform 사용법·구조
- [SCM & 협업](./scm-collaboration.md) — 브랜치 전략
- [인증 & 보안](./auth-security.md) — 시크릿(Secret Manager) SOT
- [로깅 & 모니터링](./logging-monitoring.md) — 로그 수집
