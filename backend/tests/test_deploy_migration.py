import os
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
DEPLOY_SCRIPT = ROOT / "deploy" / "deploy.sh"

# 스크립트를 실제로 실행하는 테스트는 POSIX 셸 환경을 전제한다 — 가짜 sudo/curl을 PATH에
# 얹어야 하는데, Windows에서는 PATH 구분자와 실행 비트가 달라 스텁이 잡히지 않는다.
# CI(ubuntu)에서는 그대로 실행되므로 검증 자체는 유지된다.
requires_posix_shell = pytest.mark.skipif(
    os.name == "nt",
    reason="POSIX 셸 스텁(sudo·curl)이 필요합니다. Linux CI에서 실행됩니다.",
)


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


@requires_posix_shell
def test_migration_command_failure_does_not_replace_running_api(tmp_path: Path) -> None:
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    command_log = tmp_path / "commands.log"

    # read_secret은 본문 뒤에 붙는 HTTP 상태 코드를 읽어 404(미등록)와 오류를 구분한다.
    # 상태 코드를 붙이지 않으면 스크립트가 조회 실패로 보고 배포를 중단한다.
    (fake_bin / "curl").write_text(
        """#!/usr/bin/env bash
if [[ "$*" == *metadata.google.internal* ]]; then
  echo '{"access_token":"test-token"}'
elif [[ "$*" == *secretmanager.googleapis.com* ]]; then
  printf '{"payload":{"data":"dmFsdWU="}}
200'
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


def _write_secret_stubs(fake_bin: Path, *, missing: str = "", failing: str = "") -> None:
    """Secret Manager 응답을 흉내 내는 curl 스텁 — 상태 코드를 본문 뒤에 붙여 돌려준다."""
    (fake_bin / "curl").write_text(
        f"""#!/usr/bin/env bash
if [[ "$*" == *metadata.google.internal* ]]; then
  echo '{{"access_token":"test-token"}}'; exit 0
fi
for arg in "$@"; do
  case "$arg" in
    *"/secrets/{failing or "__none__"}/"*) printf '{{"error":{{"code":403}}}}
403'; exit 0 ;;
    *"/secrets/{missing or "__none__"}/"*) printf '{{"error":{{"code":404}}}}
404'; exit 0 ;;
    *secretmanager.googleapis.com*) printf '{{"payload":{{"data":"dmFsdWU="}}}}
200'; exit 0 ;;
  esac
done
echo '{{"status":"ok"}}'
"""
    )
    # 마이그레이션 단계에서 멈춘다 — 여기까지 왔다는 것이 "시크릿 때문에 배포가 막히지
    # 않았다"는 뜻이고, 이후의 health·TLS 대기 루프(최대 3분)를 태우지 않는다.
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


def _run_deploy(tmp_path: Path, fake_bin: Path) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env.update(
        {
            "API_IMAGE": "registry.example/api:test",
            "CLOUD_SQL_CONNECTION_NAME": "project:region:instance",
            "KAKAO_APP_ID": "12345",
            "API_DOMAIN": "api.example.test",
            "HOME": str(tmp_path),
            "COMMAND_LOG": str(tmp_path / "commands.log"),
            "PATH": f"{fake_bin}:{env['PATH']}",
        }
    )
    return subprocess.run(
        ["bash", str(DEPLOY_SCRIPT)],
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )


@requires_posix_shell
def test_missing_optional_secret_warns_and_continues(tmp_path: Path) -> None:
    """미등록(404) 시크릿은 경고만 하고 배포를 계속한다 (KAN-75)."""
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    _write_secret_stubs(fake_bin, missing="colortrip-dev-gemini-api-key")

    result = _run_deploy(tmp_path, fake_bin)

    assert "WARNING: Gemini 키" in result.stdout
    assert "사진 인증이 항상 거절" in result.stdout
    # 시크릿 때문에 멈추지 않았다 — 마이그레이션 단계까지 도달했다(스텁이 42로 끊는다).
    assert result.returncode == 42
    assert "uv run alembic upgrade head" in (tmp_path / "commands.log").read_text(encoding="utf-8")


@requires_posix_shell
def test_secret_permission_error_aborts_deploy(tmp_path: Path) -> None:
    """권한 오류(403)를 '미등록'으로 삼키지 않는다 (리뷰 반영).

    삼키면 QR_SECRET_KEY가 조용히 JWT 파생값으로 바뀌어 현장에 붙인 QR이 전부
    무효화된다 — 배포는 성공한 것처럼 보이는데 인증만 깨진다.
    """
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    _write_secret_stubs(fake_bin, failing="colortrip-dev-qr-secret-key")

    result = _run_deploy(tmp_path, fake_bin)

    assert result.returncode == 1  # 마이그레이션(42)에 도달하기 전에 끊겼다
    assert "HTTP 403" in result.stderr
    # API를 교체하는 단계까지 가지 않았다.
    commands = tmp_path / "commands.log"
    assert not commands.exists() or "up -d --no-deps api" not in commands.read_text(
        encoding="utf-8"
    )


def test_read_secret_distinguishes_missing_from_failure() -> None:
    """스크립트가 상태 코드를 실제로 분기하는지 (실행 환경 무관 계약 확인)."""
    script = DEPLOY_SCRIPT.read_text(encoding="utf-8")

    assert "%{http_code}" in script
    assert "--connect-timeout 5" in script and "--max-time 20" in script
    assert 'if [ "${status}" = "404" ]; then' in script
