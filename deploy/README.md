# 배포 (Compute Engine)

운영 인스턴스(`colortrip-dev-app`)에서 Docker Compose로 앱을 구동한다. 인프라 SOT는 [docs/conventions/infra-deploy.md](../docs/conventions/infra-deploy.md).

## 구성 (현재: API 배포)

| 서비스 | 역할 |
|--------|------|
| `caddy` | TLS 종단 리버스 프록시. 80·443 점유, Let's Encrypt 인증서 자동 발급·갱신 후 `api:8000`으로 프록시 |
| `cloudsql-proxy` | Cloud SQL Auth Proxy. 인스턴스 서비스 계정(`roles/cloudsql.client`)으로 인증, `:5432` 노출 |
| `api` | FastAPI (`backend/Dockerfile`). `cloudsql-proxy:5432`로 DB 접속 |

Flutter 클라이언트 소스는 `frontend/`에 있지만 모바일 앱으로 별도 빌드·배포한다.
현재 Compute Engine compose는 백엔드 API만 운영한다.

### HTTPS

`api`는 **호스트 포트를 열지 않는다.** 외부 노출은 `caddy`만 담당하므로 평문으로 API에
직접 닿는 경로가 없다. 설계와 근거(왜 Caddy·왜 sslip.io)는
[docs/specs/065-dev-https/](../docs/specs/065-dev-https/)에 있다.

안드로이드 **릴리스 APK는 평문 HTTP를 차단**하므로(`targetSdk=36`, `usesCleartextTraffic`
미설정) HTTPS는 선택이 아니라 앱 연동의 전제 조건이다.

인증서는 `caddy-data` 볼륨에 영속화된다. 이 볼륨을 지우면 재발급이 일어나므로
Let's Encrypt rate limit에 유의한다.

## 환경변수

`.env`는 인스턴스에서 생성하며 **커밋하지 않는다**. 템플릿은 [.env.example](.env.example).
DB 비밀번호와 JWT secret 등 시크릿은 Secret Manager에서 가져와 채운다.

```bash
# DB 비밀번호를 Secret Manager에서 읽어 .env의 PASSWORD 자리에 주입하는 예시
PW=$(gcloud secrets versions access latest --secret=colortrip-dev-db-password)
PW="$PW" python3 - <<'PY' > .env
from pathlib import Path
import os
from urllib.parse import quote

text = Path(".env.example").read_text()
pw = quote(os.environ["PW"], safe="")
print(text.replace("PASSWORD", pw), end="")
PY
# 그 뒤 API_IMAGE 등 나머지 값 확인
```

필수 Secret Manager 값:

| Secret | 용도 |
|--------|------|
| `colortrip-dev-db-password` | Cloud SQL 접속 비밀번호 |
| `colortrip-dev-jwt-secret-key` | Access JWT 서명과 refresh token hash |
| `colortrip-dev-kakao-rest-api-key` | Kakao 로그인 REST API 키 |
| `colortrip-dev-kakao-redirect-uri` | Kakao authorization code 교환용 redirect URI |

선택 Secret Manager 값:

| Secret | 용도 |
|--------|------|
| `colortrip-dev-tour-api-key` | 한국관광공사 TourAPI |
| `colortrip-dev-kakao-client-secret` | Kakao client secret을 활성화한 경우 |

비밀이 아닌 값은 GitHub Actions repository **variable**로 주입한다.

| Variable | 값 | 용도 |
|----------|-----|------|
| `KAKAO_APP_ID` | `1522375` | Kakao access token의 `app_id` 검증 |
| `API_DOMAIN` | `34-64-226-70.sslip.io` | Caddy 인증서 발급 호스트명 |

`CORS_ALLOWED_ORIGINS`(콤마 구분 도메인 화이트리스트)는 `deploy.sh`에서 빈 값으로 고정한다.
현재 브라우저에서 API를 호출하는 웹 프론트가 없어 화이트리스트를 비워도 검증(`local`/`test`
외에는 `"*"` 금지)을 통과한다. 프론트 도메인이 정해지면 `deploy.sh`의 값을 실제 도메인으로
교체한다.

## 실행 (인스턴스에서)

```bash
docker compose --env-file .env up -d
docker compose logs -f api
```

확인: `curl https://34-64-226-70.sslip.io/health` → `{"status":"ok"}` 형태의 Envelope 응답.
HTTP로 접근하면 Caddy가 HTTPS로 리다이렉트한다.

## 자동화

이미지 빌드 → Artifact Registry 푸시 → 인스턴스 배포는
[deploy-dev.yml](../.github/workflows/deploy-dev.yml) GitHub Actions에서 수행한다.
이 디렉토리의 compose·env 템플릿과 `deploy.sh`를 사용한다.

배포는 다음 순서를 강제한다.

1. 새 API 이미지 pull
2. Cloud SQL Proxy 시작 및 TCP 준비 확인
3. 기존 API를 유지한 상태에서 새 이미지로 `alembic upgrade head`
4. migration 성공 시에만 API 컨테이너 교체
5. compose 내부망에서 `api:8000/health` 확인
6. **인스턴스 로컬**에서 TLS 종단·인증서 확인 — `--resolve`로 loopback을 향하므로 검증 범위는
   Caddy의 TLS 종단과 인증서 체인·호스트명까지다. 공개 DNS·방화벽·외부 라우팅은 포함하지
   않는다 (실패 시 Caddy 로그 출력)
7. **GitHub Actions 러너(인스턴스 밖)**에서 `https://${API_DOMAIN}/health` 확인 — 여기서
   공개 DNS·방화벽·외부 라우팅까지 실제로 검증된다

두 단계 모두 상태 코드가 정확히 `200`인지 비교한다(`curl --fail`은 3xx를 실패로 보지 않아
리다이렉트가 성공으로 새는 것을 막지 못한다). 모든 probe에는 연결·전체 제한 시간을 건다.

Migration 실패 시 기존 API를 교체하지 않으며 자동 downgrade하지 않는다. API 교체 후
수동 복구가 필요하면 이전 SHA 이미지 태그를 `API_IMAGE`로 지정하고 `docker compose
up -d --no-deps api`를 실행한다. 이미 적용된 개인정보 익명화 migration은 복구되지
않는다.
