#!/usr/bin/env bash
# Cloud SQL Auth Proxy 로컬 실행 헬퍼
# Cloud SQL(PostgreSQL)을 localhost로 끌어와 psql·DBeaver 등으로 쉽게 접속하기 위한 스크립트.
#
# 사전 준비(최초 1회):
#   1) ADC 로그인:        gcloud auth application-default login
#   2) cloud-sql-proxy 설치: https://cloud.google.com/sql/docs/postgres/sql-proxy#install
#      (Windows는 cloud-sql-proxy.exe 를 PATH에 두면 됩니다.)
#
# 사용:
#   ./db-proxy.sh                       # terraform output에서 연결 이름 자동 인식
#   ./db-proxy.sh PROJECT:REGION:NAME   # 연결 이름 직접 지정
#   PORT=5433 ./db-proxy.sh             # 로컬 포트 변경(기본 5432)
#
# 연결되면 다른 터미널에서:
#   psql "host=127.0.0.1 port=5432 user=<USER> dbname=<DB>"
set -euo pipefail

PORT="${PORT:-5432}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="${ENV_DIR:-$SCRIPT_DIR/../envs/dev}"

# 연결 이름(PROJECT:REGION:INSTANCE): 인자 우선, 없으면 terraform output에서 조회
CONN="${1:-}"
if [[ -z "$CONN" ]]; then
  CONN="$(terraform -chdir="$ENV_DIR" output -raw cloud_sql_connection_name 2>/dev/null || true)"
fi

if [[ -z "$CONN" ]]; then
  echo "❌ Cloud SQL 연결 이름을 찾지 못했습니다." >&2
  echo "   - Cloud SQL을 아직 안 만들었거나 terraform output에 cloud_sql_connection_name이 없습니다." >&2
  echo "   직접 지정: $0 PROJECT:REGION:INSTANCE" >&2
  exit 1
fi

if ! command -v cloud-sql-proxy >/dev/null 2>&1; then
  echo "❌ cloud-sql-proxy 가 설치되어 있지 않습니다." >&2
  echo "   설치 안내: https://cloud.google.com/sql/docs/postgres/sql-proxy#install" >&2
  exit 1
fi

echo "▶ Cloud SQL Auth Proxy: $CONN  →  localhost:$PORT   (Ctrl+C 로 종료)"
exec cloud-sql-proxy --port "$PORT" "$CONN"
