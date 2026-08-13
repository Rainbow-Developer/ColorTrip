# [컨벤션] 코드 품질 & 컨벤션

> **범위**: 린트·포맷·타입체크·커밋 전 자동 검사·테스트 정책.
> **변경 시**: 이 문서를 단일 출처로 갱신합니다 ([AGENT_GUIDE 문서 동기화](../AGENT_GUIDE.md#문서-동기화-필수) 참고).

## 결정 사항

| 항목         | 결정                                | 비고 |
|------------|-----------------------------------|------|
| Python 패키지 관리 | uv                                | |
| Python 린트/포맷 | Ruff (린트 + 포맷)                    | |
| Python 타입 체크 | Pyright                           | |
| 프론트엔드 포맷   | dart analyze + dart format        | |
| 커밋 전 자동 검사 | pre-commit 프레임워크 (Back·Front 공통)  | 프론트엔드는 dart format/analyze 훅 |
| PR 자동 검사   | GitHub Actions (`dev`로 향하는 PR·`dev` 푸시) | 백엔드 ruff+pytest, 프론트엔드 analyze+test |
| 테스트 정책     | **작성·유지 필수** (2026-08-14 변경, 이전 "초기엔 생략") | 기능 변경에는 회귀 테스트를 함께 넣는다 |
| 테스트 도구     | pytest(Back), flutter_test(Front) | |

## 규칙 / 적용

- `[강제]` **커밋 전 자동 검사** — git hook은 **pre-commit 프레임워크 한 곳**으로 일원화합니다 (`.pre-commit-config.yaml`).
  - **백엔드**: `ruff-check` (린트), `ruff-format` (포맷팅), `pyright` (타입 체크) 훅이 활성화되어 있습니다.
  - **프론트엔드**: `dart-format` (포맷팅), `flutter-analyze` (코드 분석) 훅이 활성화되어 있습니다.
- `[강제]` **PR 자동 검사(CI)** — `dev`로 향하는 PR과 `dev` 푸시에서 GitHub Actions가 테스트를 실행합니다.
  - **백엔드** ([test-backend.yml](../../.github/workflows/test-backend.yml)): PostgreSQL 서비스 컨테이너 + `ruff check`·`ruff format --check`·`pytest`.
  - **프론트엔드** ([test-frontend.yml](../../.github/workflows/test-frontend.yml)): `flutter analyze`·`flutter test`.
  - 경로 필터에 주의합니다. `frontend/lib/data/static/**`(정적 퀘스트 데이터)와 `deploy/**`는 **백엔드** 테스트가 직접 읽어 검증하므로 백엔드 워크플로의 트리거에도 포함되어 있습니다.
  - pre-commit 훅은 로컬에서 건너뛸 수 있고(`SKIP=...`), Flutter SDK가 없는 환경에서는 dart 훅이 아예 돌지 않습니다. CI가 그 구멍을 메우는 최종 방어선입니다.
- 테스트는 **작성·유지 대상**입니다. 도구는 pytest(백엔드)·flutter_test(프론트엔드)입니다.
  - 기능을 바꾸면 그 동작을 고정하는 테스트를 함께 넣습니다. 특히 **버그를 고칠 때는 그 버그를 재현하는 테스트**를 먼저 추가합니다.
  - 이미 실패 중인 테스트를 발견하면 "원래 깨져 있었다"로 넘기지 않습니다 — 실제 결함을 가리고 있을 수 있습니다. (KAN-75: `test_domain_catalog_contract`가 빨간 채 방치돼 QR 인증이 전혀 동작하지 않는 것을 아무도 몰랐습니다.)

## WHY?

### 💡 코드 스타일 & 도구

- **파이썬 표준 스타일 가이드**: `PEP 8` 준수
- **Ruff (린터 및 포매터 통합 도구)**
  - 최대 코드 한 줄 길이: `100자` (Black 표준)
  - 따옴표 규칙: 기본적으로 `"` (큰따옴표)를 사용하고, 필요한 경우에만 `'` (작은따옴표) 사용
- **Pyright (정적 타입 검사기)**
  - 작성한 코드에 타입 힌트가 규칙에 맞게 올바르게 쓰였는지 검사
  - **장점**:
    1. 기존 파이썬 표준 타입 검사기 `mypy`보다 훨씬 빠름
    2. 코드 실행 전, 타입 불일치 에러를 사전에 차단 가능
    3. CI/CD에 등록하여 개발자가 PR을 보낼 때 `pyright` 명령어가 자동 실행되도록 설정 가능 (타입 에러가 1개라도 있으면 Merge 불가능)
  - **Pyright 설치 방법**:
    ```bash
    # Poetry를 사용하는 경우
    poetry add --group dev pyright

    # uv를 사용하는 경우 (본 프로젝트 표준)
    uv pip install pyright

    # 일반 pip를 사용하는 경우
    pip install pyright
    ```
  - **터미널에서 타입 검사 실행 방법**:
    ```bash
    # 전체 프로젝트 검사
    pyright

    # 특정 디렉토리(app/)만 지정 검사
    pyright app/
    ```

### 💡 Python 패키지 관리
- Python에는 패키지 관리, 즉 라이브러리 의존성을 한 곳에 모아두고 관리해주는 도구는 Poetry와 uv가 존재 <br>
  도구가 실행되는 원리는 비슷하지만 uv를 선택한 이유는 Rust 언어로 작성되어 Poetry보다 최대 10 ~ 100배 빠름

| 기능             | Poetry             | uv (현재 프로젝트에 적용됨) |
|----------------|--------------------|-------------------|
| 의존성 정의 파일      | `pyproject.toml`   | `pyproject.toml`  |
| 버전 고정 Lock 파일  | `poetry.lock`      | `uv.lock`         |
| 명령어 하나로 환경 동기화 | `poetry install`   | `uv sync`         |
| 라이브러리 추가       | `poetry add <패키지>` | `uv add <패키지>`    |
| 가상환경 내 명령어 실행  | `poetry run <명령>`  | `uv run <명령>`     |

### 💡 같은 개발 조건을 만드는 작동 원리
1. `backend/pyproject.toml` : 이 파일의 `[project.dependencies]`와 `[dependency-groups.dev]` 영역에 프로젝트가 사용할 모든 라이브러리들을 모아둠
2. `backend/uv.lock` : 협업하는 모든 팀원들이 1바이트의 오차도 없이 완전히 동일한 버전의 라이브러리를 내려받도록 락(Lock)을 걸어둔 파일<br> (이 파일이 있기 때문에 서로 다른 PC에서도 항상 같은 환경 보장)
3. `uv sync` : 이 명령어 단 하나로 가상환경(.venv) 생성부터 uv.lock에 명세된 모든 라이브러리를 동기화하는 작업까지 처리

따라서 우리는 같은 Back 환경을 구축하기 위해서 `/backend` 디렉토리 이동 후 명령어 실행
```bash
uv sync --group dev
```

---

## 🛠️ 개발자 로컬 환경 세팅 가이드

이 규칙들을 로컬 개발 환경에 적용하기 위한 세팅 방법입니다.

### 1. 백엔드 (Python/FastAPI) 의존성 설치
백엔드 린터와 타입 체커가 원활히 작동하려면 로컬에 `uv` 및 백엔드 개발 의존성 패키지들이 설치되어 있어야 합니다.
```bash
# 1. uv가 설치되어 있지 않다면 설치 (Mac/Homebrew)
brew install uv

# 2. backend 폴더로 이동하여 개발 의존성 동기화
cd backend
uv sync --group dev
```
> [NOTE] <br>
> **Ruff와 Pyright 수동 설치 여부**: <br>
> 개발자가 시스템 전역에 `Ruff`나 `Pyright`를 개별적으로 다운로드하여 설치할 필요는 없습니다. `uv sync --group dev`를 실행하면 프로젝트의 개발 의존성 그룹에 정의된 패키지들이 가상환경(`.venv`) 내에 자동으로 설치됩니다.
> 단, 코드 작성 중 실시간으로 문법 에러 및 포맷 오류를 IDE에서 보려면, **VS Code의 Ruff/Pyright 확장(Extension)** 혹은 **PyCharm의 Ruff 플러그인**을 별도로 마켓플레이스에서 설치하는 것이 매우 편리합니다.

### 2. pre-commit 설치 및 훅 등록
Git 커밋 시점에 자동으로 검사 훅이 실행되도록 설정합니다.
```bash
# 1. pre-commit 도구 설치
brew install pre-commit  # 또는 uv tool install pre-commit

# 2. 프로젝트 루트(/ColorTrip)에서 git hook 등록
pre-commit install --install-hooks
```

### 3. 수동 검사 및 테스트
커밋을 하지 않고도 프로젝트 전체 코드의 품질을 수동으로 점검하고 싶을 때는 아래 명령어를 실행합니다.
```bash
# 전체 파일에 대해 모든 pre-commit 검사 수행
pre-commit run --all-files
```

## 관련 문서

- [형상 관리 & 협업](./scm-collaboration.md)
- [AGENT_GUIDE](../AGENT_GUIDE.md)
