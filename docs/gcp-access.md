# GCP 리소스 · 접근 정보 (팀 공유용)

> 팀원이 GCP·배포·로컬 개발에 접근할 때 필요한 **실제 값과 접근 방법**을 한곳에 모은 참고 문서입니다.
> 인프라 **결정의 단일 출처(SOT)** 는 [conventions/infra-deploy.md](conventions/infra-deploy.md), 시크릿 정책 SOT 는 [conventions/auth-security.md](conventions/auth-security.md) 입니다. 이 문서는 그 결정에 대응하는 **구체적 리소스 값·접근 절차**를 담습니다.
>
> ⚠️ **시크릿(비밀번호·API 키·JWT 키)은 이 문서에 절대 적지 않습니다.** 모두 GCP Secret Manager 에 있고, 아래 [시크릿](#시크릿-secret-manager) 절차로 꺼내 씁니다. 여기 적힌 값(프로젝트 ID·IP·서비스 계정 이메일 등)은 비밀이 아닌 식별자입니다.

## 사전 준비 (최초 1회)

```bash
gcloud auth login                          # GCP 콘솔 계정 로그인
gcloud config set project colortrip        # 기본 프로젝트 지정
gcloud auth application-default login      # ADC (Terraform·Cloud SQL Proxy 용)
```

- **프로젝트 접근 권한**이 필요합니다. 없으면 프로젝트 오너에게 `colortrip` 프로젝트 IAM 초대를 요청하세요.
- Terraform >= 1.5, `cloud-sql-proxy`, `gcloud` CLI 설치가 필요합니다.

## GCP 프로젝트

| 항목 | 값 |
|------|------|
| 프로젝트 ID | `colortrip` |
| 프로젝트 번호 | `190304972522` |
| 리전 | `asia-northeast3` (서울) |
| 존(zone) | `asia-northeast3-a` |
| 환경 | `dev` (현재 가동 중) · `prod`(예정) |

## dev 환경 리소스 (가동 중)

| 리소스 | 값 | 비고 |
|--------|------|------|
| Compute Engine 인스턴스 | `colortrip-dev-app` | Ubuntu + Docker, `e2-small` |
| 인스턴스 외부 IP(고정) | `34.64.226.70` | 80·443만 공개(SSH는 IAP 전용) |
| API 주소 (HTTPS) | `https://34-64-226-70.sslip.io` | 검증: `curl https://34-64-226-70.sslip.io/health`. sslip.io 임시 도메인 — [065-dev-https](specs/065-dev-https/) |
| Cloud SQL 인스턴스 | `colortrip-dev-db` | PostgreSQL 16, `db-g1-small` |
| Cloud SQL 연결 이름 | `colortrip:asia-northeast3:colortrip-dev-db` | Auth Proxy 용 |
| DB 이름 / 유저 | `colortrip` / `colortrip` | 비밀번호는 Secret Manager |
| Artifact Registry | `asia-northeast3-docker.pkg.dev/colortrip/colortrip-dev` | Docker 이미지 저장소 |
| VPC / 서브넷 | `colortrip-dev` / `colortrip-dev-subnet` | 서브넷 CIDR `10.10.0.0/24` |
| Terraform 상태 버킷 | `gs://colortrip-tfstate` (prefix `envs/dev`) | 버전 관리 활성 |

> DB 는 인터넷에 직접 노출하지 않습니다(공인 IP authorized networks 없음). 반드시 Cloud SQL Auth Proxy 로 접속합니다.

## 서비스 계정

| 서비스 계정 | 이메일 | 용도 |
|------|------|------|
| 앱(App) | `colortrip-dev-app@colortrip.iam.gserviceaccount.com` | 인스턴스에 부착. Artifact pull·Cloud SQL client·Secret 읽기·로그/메트릭 |
| 배포자(Deployer) | `colortrip-dev-deployer@colortrip.iam.gserviceaccount.com` | GitHub Actions 가 WIF 로 임퍼소네이션(이미지 push·IAP SSH 배포) |

> 서비스 계정 **키 파일은 발급하지 않습니다.** 로컬은 사용자 계정(ADC), CI/CD 는 Workload Identity Federation(키리스)으로 인증합니다.

## CI/CD (GitHub Actions · WIF)

GitHub Actions 가 키 없이 GCP 에 인증하도록 Workload Identity Federation 을 씁니다. 신뢰 대상 저장소는 **`Rainbow-Developer/ColorTrip`** 이며, 이 repo 에서 발급된 OIDC 토큰만 허용됩니다.

GitHub repo Actions variables 에 넣을 값:

| Variable 이름(GitHub) | 값 |
|------|------|
| `WIF_PROVIDER` | `projects/190304972522/locations/global/workloadIdentityPools/colortrip-dev-gh-pool/providers/github` |
| `DEPLOY_SA` | `colortrip-dev-deployer@colortrip.iam.gserviceaccount.com` |
| `KAKAO_APP_ID` | Kakao token info의 `app_id`와 일치하는 양의 정수 앱 ID |
| `API_DOMAIN` | `34-64-226-70.sslip.io` — Caddy가 Let's Encrypt 인증서를 발급받을 호스트명 |

> `API_DOMAIN`이 없거나 호스트명 형식이 아니면 배포가 시작 단계에서 실패합니다([deploy-dev.yml](../.github/workflows/deploy-dev.yml)). 정식 도메인을 구매하면 이 값만 교체하면 됩니다 — [065-dev-https](specs/065-dev-https/).

네 값은 인증 비밀값이 아니라 WIF provider·서비스 계정·Kakao 앱·API 호스트명을 가리키는 식별자이므로 GitHub repository variables 로 관리합니다. Actions 는 OIDC 토큰으로 단기 자격 증명을 발급받으며, 서비스 계정 키나 앱 시크릿을 GitHub 에 저장하지 않습니다. 실제 앱 시크릿은 아래 GCP Secret Manager 에서 관리합니다.

## 시크릿 (Secret Manager)

시크릿 **값은 코드/깃/문서에 두지 않습니다**. Secret Manager 에서 이름으로 꺼냅니다.

```bash
gcloud secrets versions access latest --secret=<시크릿-이름>
```

| Secret 이름 | 용도 | 필수 여부 |
|--------|------|------|
| `colortrip-dev-db-password` | Cloud SQL 접속 비밀번호 | 필수 |
| `colortrip-dev-jwt-secret-key` | Access JWT 서명 · refresh token hash | 필수 |
| `colortrip-dev-kakao-rest-api-key` | Kakao 로그인 REST API 키 | 필수 |
| `colortrip-dev-kakao-redirect-uri` | Kakao authorization code 교환 redirect URI | 필수 |
| `colortrip-dev-kakao-client-secret` | Kakao client secret을 활성화한 경우 authorization code 교환 | 선택 |
| `colortrip-dev-tour-api-key` | 한국관광공사 TourAPI | 선택 |

## 접근 방법

### 인스턴스 SSH (IAP 터널)

```bash
gcloud compute ssh colortrip-dev-app --zone=asia-northeast3-a --tunnel-through-iap
```

### Cloud SQL 로컬 접속 (Auth Proxy)

```bash
cd infra/scripts && ./db-proxy.sh          # localhost:5432 로 프록시 오픈
# 다른 터미널에서
psql "host=127.0.0.1 port=5432 user=colortrip dbname=colortrip"
```

비밀번호는 `gcloud secrets versions access latest --secret=colortrip-dev-db-password` 로 확인합니다.

### 컨테이너 이미지 push/pull

```bash
gcloud auth configure-docker asia-northeast3-docker.pkg.dev
```

## 로컬 개발 (.env)

백엔드는 `backend/.env` 에서 설정을 읽습니다(pydantic-settings). `.env` 는 **커밋되지 않습니다**.

```bash
cp backend/.env.example backend/.env       # 템플릿 복사 후 값 채우기
docker compose up                          # PostgreSQL + FastAPI 로컬 구동
```

- `APP_ENV=local`에서는 JWT 기본값과 빈 REST key·redirect URI를 허용하지만, `KAKAO_APP_ID`는 모든 환경에서 필요한 양의 정수 설정입니다.
- 실제 Kakao 로그인·TourAPI 를 로컬에서 테스트하려면 위 [시크릿](#시크릿-secret-manager) 명령으로 값을 받아 `.env` 에 채웁니다. `KAKAO_APP_ID`는 시크릿이 아니므로 Kakao Developers 앱 정보의 숫자 앱 ID를 직접 설정합니다.
- 운영 인스턴스용 `.env` 생성 절차는 [deploy/README.md](../deploy/README.md) 참고(Secret Manager 에서 DB 비밀번호 주입).

## 관련 문서

- [conventions/infra-deploy.md](conventions/infra-deploy.md) — 인프라 결정 SOT
- [conventions/auth-security.md](conventions/auth-security.md) — 시크릿·인증 정책 SOT
- [infra/README.md](../infra/README.md) — Terraform 사용법·구조
- [deploy/README.md](../deploy/README.md) — 인스턴스 배포·운영 `.env`
