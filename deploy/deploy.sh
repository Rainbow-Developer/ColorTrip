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
GEMINI_SECRET="colortrip-dev-gemini-api-key" # 없으면 사진 인증이 거절된다(경고)
QR_SECRET_NAME="colortrip-dev-qr-secret-key" # 없으면 JWT 키에서 파생(경고)

# 인스턴스 서비스 계정 액세스 토큰(메타데이터 서버)
TOKEN="$(curl -s -H 'Metadata-Flavor: Google' \
  'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token' \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')"

# Secret Manager에서 값 읽기.
#
# **시크릿 없음(404)과 조회 실패(권한·장애)를 구분한다** — 예전에는 둘 다 빈 문자열이라,
# 403이나 5xx가 나도 "시크릿 미등록"으로 취급돼 배포가 그대로 진행됐다. 그러면 예컨대
# QR_SECRET_KEY가 조용히 JWT 파생값으로 바뀌어 현장에 붙인 QR이 전부 무효화된다(리뷰 반영).
#
# 404: 빈 문자열 + exit 0 (선택 시크릿은 호출부가 경고만 하고 진행)
# 그 외 오류(401·403·5xx·응답 파싱 실패·네트워크): exit 1 → set -e로 배포 중단
read_secret() {
  local name="$1" response status body
  # --max-time 없이 두면 메타데이터·API 정체 시 배포가 무기한 매달린다.
  response="$(curl -s --connect-timeout 5 --max-time 20 -w $'\n%{http_code}' \
    -H "Authorization: Bearer ${TOKEN}" \
    "https://secretmanager.googleapis.com/v1/projects/${PROJECT}/secrets/${name}/versions/latest:access")" || {
    echo "ERROR: 시크릿(${name}) 조회 요청 실패 (네트워크·타임아웃)" >&2
    return 1
  }
  status="${response##*$'\n'}"
  body="${response%$'\n'*}"

  if [ "${status}" = "404" ]; then
    return 0 # 미등록 — 선택 시크릿이면 호출부가 경고 후 진행한다
  fi
  if [ "${status}" != "200" ]; then
    echo "ERROR: 시크릿(${name}) 조회 실패 (HTTP ${status})" >&2
    return 1
  fi

  BODY="${body}" python3 -c 'import sys,os,json,base64
try:
    payload = json.loads(os.environ["BODY"]).get("payload", {}).get("data")
except json.JSONDecodeError:
    sys.exit("ERROR: 시크릿 응답을 해석하지 못했습니다.")
if payload is None:
    sys.exit("ERROR: 시크릿 응답에 payload가 없습니다.")
sys.stdout.write(base64.b64decode(payload).decode())'
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

# 퀘스트 인증 3종 관련 시크릿(docs/specs/050-quest-verification). **미등록(404)일 때만**
# 배포를 계속하되 어떤 기능이 죽는지 로그로 드러낸다 — 조용히 넘어가면 "인증이 안 된다"를
# 나중에 앱에서 발견하게 된다(KAN-75에서 실제로 그랬다). 권한 오류·장애는 read_secret이
# 실패로 처리해 여기서 배포가 멈춘다(set -e).
GEMINI_KEY="$(read_secret "${GEMINI_SECRET}")"
if [ -z "${GEMINI_KEY}" ]; then
  echo "WARNING: Gemini 키(${GEMINI_SECRET}) 없음 — APP_ENV=dev는 fail-closed라 사진 인증이 항상 거절됩니다."
fi
QR_KEY="$(read_secret "${QR_SECRET_NAME}")"
if [ -z "${QR_KEY}" ]; then
  echo "WARNING: QR 서명 키(${QR_SECRET_NAME}) 없음 — JWT_SECRET_KEY 파생값을 씁니다."
  echo "         JWT 키를 교체하면 현장에 붙인 QR이 전부 무효화됩니다."
fi
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
TOUR_API_KEY=${TOUR_KEY}
TOUR_API_BASE_URL=https://apis.data.go.kr/B551011/KorService2
GEMINI_API_KEY=${GEMINI_KEY}
QR_SECRET_KEY=${QR_KEY}
# 인증 사진 저장 위치. compose의 api-uploads 볼륨에 마운트해 재배포에도 남긴다
# (GCS 전환 전까지의 임시 조치 — GCS_UPLOAD_BUCKET이 설정되면 이 값은 쓰이지 않는다).
UPLOAD_DIR=/app/uploads
# 아직 브라우저에서 호출하는 웹 프론트가 없어 화이트리스트 비움. 프론트 도메인이 정해지면 채운다.
CORS_ALLOWED_ORIGINS=
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
#
# ⚠️ 비-additive migration(컬럼·테이블 DROP, NOT NULL 추가, 타입 변경)은 이 순서에서
#    아래 두 가지를 감수한다. 출시 후에는 2단계 배포로 나눠야 한다
#    (docs/conventions/infra-deploy.md "비-additive 스키마 변경").
#
#    1. 짧은 5xx 구간 — 여기서 스키마가 바뀌고 나서 다음 줄의 컨테이너 교체가 끝날
#       때까지, 구 이미지가 사라진 컬럼을 SELECT 하다 실패한다(보통 수 초).
#    2. 롤백 불가 — 구 이미지는 새 스키마에서 아예 뜨지 않으므로 이미지만 되돌릴 수
#       없다. 되돌리려면 alembic downgrade를 수동 실행해야 하고, DROP된 데이터는
#       돌아오지 않는다. 사실상 fix-forward만 가능하다.
sudo docker compose run --rm --no-deps api uv run alembic upgrade head

sudo docker compose up -d --no-deps api
sudo docker compose up -d --no-deps caddy

# api 는 호스트 포트를 열지 않으므로 compose 내부망에서 확인한다.
# wget 자체 타임아웃(-T)과 바깥 timeout 을 함께 건다 — 전자는 응답을 기다리다 멈추는 것을,
# 후자는 docker compose exec 자체가 붙잡히는 것을 막는다.
echo "API health 확인(내부망)"
api_healthy=0
for _ in $(seq 1 30); do
  if timeout 15s sudo docker compose exec -T caddy \
      wget -q -T 5 -O /dev/null http://api:8000/health; then
    api_healthy=1
    break
  fi
  sleep 2
done
[ "${api_healthy}" -eq 1 ] || { echo "ERROR: API health 확인 실패"; exit 1; }

# Let's Encrypt 발급까지 시간이 걸리므로 넉넉히 대기한다.
# --resolve 로 자기 자신(loopback)을 가리키므로 이 검사가 보장하는 것은 **TLS 종단과 인증서**
# 까지다(hairpin NAT 의존을 피하려는 의도). 공개 DNS·방화벽·외부 라우팅은 검증하지 않으며,
# 그건 워크플로의 "Verify public HTTPS" 스텝이 인스턴스 밖에서 담당한다.
# -k 를 쓰지 않으므로 인증서 체인·호스트명은 여기서 실제로 검증된다.
# --fail 은 3xx 를 실패로 보지 않아 리다이렉트가 성공으로 새는 것을 막지 못하므로,
# 상태 코드를 직접 200 과 비교한다.
echo "TLS 종단·인증서 확인(${API_DOMAIN}, 인스턴스 로컬)"
https_ready=0
for _ in $(seq 1 60); do
  code="$(curl --silent --show-error --connect-timeout 5 --max-time 10 \
    --resolve "${API_DOMAIN}:443:127.0.0.1" \
    --output /dev/null --write-out '%{http_code}' \
    "https://${API_DOMAIN}/health" || true)"
  if [ "${code}" = "200" ]; then
    https_ready=1
    break
  fi
  sleep 3
done
if [ "${https_ready}" -ne 1 ]; then
  echo "ERROR: TLS 확인 실패 (마지막 응답 코드: '${code:-없음}') — Caddy 로그:"
  sudo docker compose logs --tail 50 caddy
  exit 1
fi

sudo docker image prune -f
echo "deploy 완료: ${API_IMAGE}"
