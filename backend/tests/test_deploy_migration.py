import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEPLOY_SCRIPT = ROOT / "deploy" / "deploy.sh"


def test_deploy_runs_migration_before_replacing_api() -> None:
    script = DEPLOY_SCRIPT.read_text(encoding="utf-8")

    pull = script.index("docker compose pull")
    proxy = script.index("docker compose up -d cloudsql-proxy")
    database_ready = script.index('echo "Cloud SQL Proxy 준비 확인"')
    migration = script.index("uv run alembic upgrade head")
    replace_api = script.index("docker compose up -d --no-deps api")
    health = script.index('echo "API health 확인(내부망)"')

    assert pull < proxy < database_ready < migration < replace_api < health


def test_deploy_fails_before_api_replacement_when_migration_fails() -> None:
    script = DEPLOY_SCRIPT.read_text(encoding="utf-8")

    assert "set -euo pipefail" in script
    assert "uv run alembic upgrade head" in script
    assert "자동 downgrade하지 않는다" in script


def test_migration_command_failure_does_not_replace_running_api(tmp_path: Path) -> None:
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    command_log = tmp_path / "commands.log"

    (fake_bin / "curl").write_text(
        """#!/usr/bin/env bash
if [[ "$*" == *metadata.google.internal* ]]; then
  echo '{"access_token":"test-token"}'
elif [[ "$*" == *secretmanager.googleapis.com* ]]; then
  echo '{"payload":{"data":"dmFsdWU="}}'
else
  echo '{"status":"ok"}'
fi
"""
    )
    (fake_bin / "sudo").write_text(
        """#!/usr/bin/env bash
echo "$*" >> "${COMMAND_LOG}"
if [[ "$*" == *"uv run alembic upgrade head"* ]]; then
  exit 42
fi
exit 0
"""
    )
    for executable in ("curl", "sudo"):
        (fake_bin / executable).chmod(0o755)

    env = os.environ.copy()
    env.update(
        {
            "API_IMAGE": "registry.example/api:test",
            "CLOUD_SQL_CONNECTION_NAME": "project:region:instance",
            "KAKAO_APP_ID": "12345",
            "API_DOMAIN": "api.example.test",  # 065-dev-https에서 필수가 됐다
            "HOME": str(tmp_path),
            "COMMAND_LOG": str(command_log),
            "PATH": f"{fake_bin}:{env['PATH']}",
        }
    )
    result = subprocess.run(
        ["bash", str(DEPLOY_SCRIPT)],
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )

    commands = command_log.read_text(encoding="utf-8")
    assert result.returncode == 42
    assert "uv run alembic upgrade head" in commands
    assert "docker compose up -d --no-deps api" not in commands


def test_deploy_passes_required_kakao_app_configuration() -> None:
    script = DEPLOY_SCRIPT.read_text(encoding="utf-8")

    assert ': "${KAKAO_APP_ID:?KAKAO_APP_ID 필요}"' in script
    assert "KAKAO_APP_ID=${KAKAO_APP_ID}" in script
    assert "KAKAO_TOKEN_INFO_URL=https://kapi.kakao.com/v1/user/access_token_info" in script


def test_deploy_injects_quest_verification_secrets() -> None:
    """사진·QR 인증 시크릿을 컨테이너 환경으로 넘긴다 (KAN-75).

    dev .env에 이 둘이 없어 사진 인증은 fail-closed로 항상 거절되고, QR 서명 키는
    JWT_SECRET_KEY 파생값에 묶여 있었다(JWT 교체 시 현장 QR 전량 무효).
    """
    script = DEPLOY_SCRIPT.read_text(encoding="utf-8")

    assert 'GEMINI_SECRET="colortrip-dev-gemini-api-key"' in script
    assert 'QR_SECRET_NAME="colortrip-dev-qr-secret-key"' in script
    assert "GEMINI_API_KEY=${GEMINI_KEY}" in script
    assert "QR_SECRET_KEY=${QR_KEY}" in script
    # 업로드는 볼륨 경로로 고정해야 재배포에도 인증 사진이 남는다.
    assert "UPLOAD_DIR=/app/uploads" in script


def test_deploy_compose_persists_uploaded_photos() -> None:
    compose = (ROOT / "deploy" / "docker-compose.yml").read_text(encoding="utf-8")

    assert "api-uploads:/app/uploads" in compose
