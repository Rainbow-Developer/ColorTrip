import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEPLOY_SCRIPT = ROOT / "deploy" / "deploy.sh"


def test_deploy_runs_migration_before_replacing_api() -> None:
    script = DEPLOY_SCRIPT.read_text()

    pull = script.index("docker compose pull")
    proxy = script.index("docker compose up -d cloudsql-proxy")
    database_ready = script.index('echo "Cloud SQL Proxy 준비 확인"')
    migration = script.index("uv run alembic upgrade head")
    replace_api = script.index("docker compose up -d --no-deps api")
    health = script.index('echo "API health 확인"')

    assert pull < proxy < database_ready < migration < replace_api < health


def test_deploy_fails_before_api_replacement_when_migration_fails() -> None:
    script = DEPLOY_SCRIPT.read_text()

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

    commands = command_log.read_text()
    assert result.returncode == 42
    assert "uv run alembic upgrade head" in commands
    assert "docker compose up -d --no-deps api" not in commands


def test_deploy_passes_required_kakao_app_configuration() -> None:
    script = DEPLOY_SCRIPT.read_text()

    assert ': "${KAKAO_APP_ID:?KAKAO_APP_ID 필요}"' in script
    assert "KAKAO_APP_ID=${KAKAO_APP_ID}" in script
    assert "KAKAO_TOKEN_INFO_URL=https://kapi.kakao.com/v1/user/access_token_info" in script
