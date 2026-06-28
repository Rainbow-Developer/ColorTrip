#!/usr/bin/env bash
# 인스턴스에서 실행되는 배포 스크립트. GitHub Actions가 IAP SSH로 호출한다.
# 필수 env: API_IMAGE, CLOUD_SQL_CONNECTION_NAME
# 시크릿(DB 비번 등)은 인스턴스 서비스 계정으로 Secret Manager에서 직접 읽는다(키 없음).
set -euo pipefail

: "${API_IMAGE:?API_IMAGE 필요}"
: "${CLOUD_SQL_CONNECTION_NAME:?CLOUD_SQL_CONNECTION_NAME 필요}"

PROJECT="colortrip"
REGION="asia-northeast3"
DB_SECRET="colortrip-dev-db-password"
TOUR_SECRET="colortrip-dev-tour-api-key" # 없으면 빈 값

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
TOUR_KEY="$(read_secret "${TOUR_SECRET}")"

# Artifact Registry 도커 인증(메타데이터 토큰)
echo "${TOKEN}" | sudo docker login -u oauth2accesstoken --password-stdin "https://${REGION}-docker.pkg.dev"

cd "${HOME}" # CI가 docker-compose.yml 을 여기로 scp 한다

cat > .env <<EOF
API_IMAGE=${API_IMAGE}
CLOUD_SQL_CONNECTION_NAME=${CLOUD_SQL_CONNECTION_NAME}
DATABASE_URL=postgresql+asyncpg://colortrip:${DB_PW}@cloudsql-proxy:5432/colortrip
TOUR_API_KEY=${TOUR_KEY}
TOUR_API_BASE_URL=https://apis.data.go.kr/B551011/KorService2
EOF
chmod 600 .env

sudo docker compose pull
sudo docker compose up -d
sudo docker image prune -f
echo "deploy 완료: ${API_IMAGE}"
