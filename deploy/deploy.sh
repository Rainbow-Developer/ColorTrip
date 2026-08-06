#!/usr/bin/env bash
# 인스턴스에서 실행되는 배포 스크립트. GitHub Actions가 IAP SSH로 호출한다.
# 필수 env: API_IMAGE, CLOUD_SQL_CONNECTION_NAME, KAKAO_APP_ID, API_DOMAIN
# 시크릿(DB 비번 등)은 인스턴스 서비스 계정으로 Secret Manager에서 직접 읽는다(키 없음).
set -euo pipefail

: "${API_IMAGE:?API_IMAGE 필요}"
: "${CLOUD_SQL_CONNECTION_NAME:?CLOUD_SQL_CONNECTION_NAME 필요}"
: "${KAKAO_APP_ID:?KAKAO_APP_ID 필요}"
# Caddy가 이 호스트명으로 Let's Encrypt 인증서를 발급받는다(docs/specs/065-dev-https/).
: "${API_DOMAIN:?API_DOMAIN 필요}"

PROJECT="colortrip"
REGION="asia-northeast3"
DB_SECRET="colortrip-dev-db-password"
JWT_SECRET="colortrip-dev-jwt-secret-key"
TOUR_SECRET="colortrip-dev-tour-api-key" # 없으면 빈 값
KAKAO_REST_SECRET="colortrip-dev-kakao-rest-api-key"
KAKAO_REDIRECT_SECRET="colortrip-dev-kakao-redirect-uri"
KAKAO_CLIENT_SECRET_NAME="colortrip-dev-kakao-client-secret"

# 인스턴스 서비스 계정 액세스 토큰(메타데이터 서버)
TOKEN="$(curl -s -H 'Metadata-Flavor: Google' \
  'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token' \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')"

# Secret Manager에서 값 읽기(없으면 빈 문자열)
read_secret() {
  curl -s -H "Authorization: Bearer ${TOKEN}" \
    "https://secretmanager.googleapis.com/v1/projects/${PROJECT}/secrets/$1/versions/latest:access" \
  | python3 -c 'import sys,json,base64
d=json.load(sys.stdin); p=d.get("payload",{}).get("data")
sys.stdout.write(base64.b64decode(p).decode() if p else "")'
}

DB_PW="$(read_secret "${DB_SECRET}")"
[ -n "${DB_PW}" ] || { echo "ERROR: DB 비밀번호(${DB_SECRET}) 조회 실패"; exit 1; }
JWT_KEY="$(read_secret "${JWT_SECRET}")"
[ -n "${JWT_KEY}" ] || { echo "ERROR: JWT secret(${JWT_SECRET}) 조회 실패"; exit 1; }
TOUR_KEY="$(read_secret "${TOUR_SECRET}")"
KAKAO_REST_KEY="$(read_secret "${KAKAO_REST_SECRET}")"
[ -n "${KAKAO_REST_KEY}" ] || { echo "ERROR: Kakao REST API 키(${KAKAO_REST_SECRET}) 조회 실패"; exit 1; }
KAKAO_REDIRECT_URI="$(read_secret "${KAKAO_REDIRECT_SECRET}")"
[ -n "${KAKAO_REDIRECT_URI}" ] || { echo "ERROR: Kakao redirect URI(${KAKAO_REDIRECT_SECRET}) 조회 실패"; exit 1; }
KAKAO_CLIENT_SECRET="$(read_secret "${KAKAO_CLIENT_SECRET_NAME}")"
DB_PW_ENCODED="$(DB_PW="${DB_PW}" python3 - <<'PY'
import os
from urllib.parse import quote

print(quote(os.environ["DB_PW"], safe=""))
PY
)"

# Artifact Registry 도커 인증(메타데이터 토큰)
echo "${TOKEN}" | sudo docker login -u oauth2accesstoken --password-stdin "https://${REGION}-docker.pkg.dev"

cd "${HOME}" # CI가 docker-compose.yml 을 여기로 scp 한다

cat > .env <<EOF
API_IMAGE=${API_IMAGE}
CLOUD_SQL_CONNECTION_NAME=${CLOUD_SQL_CONNECTION_NAME}
API_DOMAIN=${API_DOMAIN}
APP_ENV=dev
LOG_LEVEL=${LOG_LEVEL:-INFO}
DATABASE_URL=postgresql+asyncpg://colortrip:${DB_PW_ENCODED}@cloudsql-proxy:5432/colortrip
JWT_SECRET_KEY=${JWT_KEY}
ACCESS_TOKEN_TTL_MINUTES=15
REFRESH_TOKEN_TTL_DAYS=14
KAKAO_REST_API_KEY=${KAKAO_REST_KEY}
KAKAO_REDIRECT_URI=${KAKAO_REDIRECT_URI}
KAKAO_APP_ID=${KAKAO_APP_ID}
KAKAO_TOKEN_INFO_URL=https://kapi.kakao.com/v1/user/access_token_info
KAKAO_CLIENT_SECRET=${KAKAO_CLIENT_SECRET}
# local/test 밖에서는 "*"가 거부된다. 네이티브 앱 요청엔 Origin이 없어 CORS와 무관하고,
# 실제로 브라우저에서 열리는 건 API가 서빙하는 공유 랜딩 페이지라 자기 오리진을 넣는다.
CORS_ALLOWED_ORIGINS=https://${API_DOMAIN}
TOUR_API_KEY=${TOUR_KEY}
TOUR_API_BASE_URL=https://apis.data.go.kr/B551011/KorService2
EOF
chmod 600 .env

sudo docker compose pull
sudo docker compose up -d cloudsql-proxy

echo "Cloud SQL Proxy 준비 확인"
database_ready=0
for _ in $(seq 1 30); do
  if sudo docker compose run --rm --no-deps api \
    python -c 'import socket; socket.create_connection(("cloudsql-proxy", 5432), timeout=2).close()'
  then
    database_ready=1
    break
  fi
  sleep 2
done
[ "${database_ready}" -eq 1 ] || { echo "ERROR: Cloud SQL Proxy 준비 시간 초과"; exit 1; }

echo "Alembic migration 적용"
# migration 실패 시 set -e에 의해 기존 API를 교체하기 전에 종료한다.
# 개인정보 익명화는 되돌릴 수 없으므로 자동 downgrade하지 않는다.
sudo docker compose run --rm --no-deps api uv run alembic upgrade head

sudo docker compose up -d --no-deps api
sudo docker compose up -d --no-deps caddy

# api 는 호스트 포트를 열지 않으므로 compose 내부망에서 확인한다.
echo "API health 확인(내부망)"
api_healthy=0
for _ in $(seq 1 30); do
  if sudo docker compose exec -T caddy wget -q -O /dev/null http://api:8000/health; then
    api_healthy=1
    break
  fi
  sleep 2
done
[ "${api_healthy}" -eq 1 ] || { echo "ERROR: API health 확인 실패"; exit 1; }

# Let's Encrypt 발급까지 시간이 걸리므로 넉넉히 대기한다. --resolve 로 자기 자신을 가리켜
# hairpin NAT 의존 없이 확인하되, -k 를 쓰지 않아 인증서 체인·호스트명까지 실제로 검증한다.
echo "HTTPS 인증서 확인(${API_DOMAIN})"
https_ready=0
for _ in $(seq 1 60); do
  if curl --fail --silent --show-error \
      --resolve "${API_DOMAIN}:443:127.0.0.1" \
      "https://${API_DOMAIN}/health" >/dev/null; then
    https_ready=1
    break
  fi
  sleep 3
done
if [ "${https_ready}" -ne 1 ]; then
  echo "ERROR: HTTPS 확인 실패 — Caddy 로그:"
  sudo docker compose logs --tail 50 caddy
  exit 1
fi

sudo docker image prune -f
echo "deploy 완료: ${API_IMAGE}"
