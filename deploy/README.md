# 배포 (Compute Engine)

운영 인스턴스(`colortrip-dev-app`)에서 Docker Compose로 앱을 구동한다. 인프라 SOT는 [docs/conventions/infra-deploy.md](../docs/conventions/infra-deploy.md).

## 구성 (현재: BE 중심)

| 서비스 | 역할 |
|--------|------|
| `cloudsql-proxy` | Cloud SQL Auth Proxy. 인스턴스 서비스 계정(`roles/cloudsql.client`)으로 인증, `:5432` 노출 |
| `api` | FastAPI (`backend/Dockerfile`). `cloudsql-proxy:5432`로 DB 접속 |
| `web` *(예정)* | nginx + Flutter Web. **`frontend/lib` 소스가 repo에 커밋된 뒤** 추가 |

> FE 소스(`frontend/lib`)가 아직 repo에 없어 `web`은 보류 중이다. 현재는 `api`를 80포트로 직접 노출해 검증한다. FE가 들어오면 nginx가 80/443을 맡고 `/api`를 백엔드로 프록시한다.

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

## 실행 (인스턴스에서)

```bash
docker compose --env-file .env up -d
docker compose logs -f api
```

확인: `curl http://localhost/health` → `{"status":"ok"}` 형태의 Envelope 응답.

## 자동화

이미지 빌드 → Artifact Registry 푸시 → 인스턴스 배포는 **GitHub Actions(CI/CD)** 에서 수행한다(구축 예정). 이 디렉토리의 compose·env 템플릿을 그대로 사용한다.
