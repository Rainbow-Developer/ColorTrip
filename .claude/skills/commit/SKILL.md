---
name: commit
description: ColorTrip에서 브랜치를 만들거나 커밋할 때 따르는 절차. 보호 브랜치(dev/main) 직접 작업 금지, 브랜치 네이밍 type/이슈번호-설명, 커밋 메시지 Conventional Commits를 지켜 HOOK 차단에 걸리지 않게 한다. "커밋해", "브랜치 만들어", "commit" 등 요청 시 사용한다. PR 제출은 dev-pr 스킬을 쓴다.
---

# commit — 브랜치·커밋 규약 절차

ColorTrip의 형상 관리 규약을 따라 브랜치를 만들고 커밋한다. 규약의 단일 출처는
[docs/conventions/scm-collaboration.md](../../../docs/conventions/scm-collaboration.md)이며,
아래 규칙은 HOOK(`.claude/hooks/`)으로 자동 검사되므로 위반하면 커밋·푸시가 차단된다.

## 1. 보호 브랜치 확인

현재 브랜치를 확인한다. `dev`·`main`은 보호 브랜치라 **직접 커밋·푸시할 수 없다**.

```bash
git rev-parse --abbrev-ref HEAD
```

보호 브랜치에 있으면 새 작업 브랜치를 만든다(아래 2).

## 2. 브랜치 네이밍

형식: `<type>/<이슈번호>-<설명>`

- `type`: `feat` `fix` `docs` `style` `refactor` `perf` `test` `build` `ci` `chore` `revert`
- `이슈번호`: 숫자 또는 Jira 키(예: `123`, `CT-123`)
- `설명`: 소문자·하이픈 (kebab-case)

```bash
git switch -c feat/123-add-kakao-login
```

예) `feat/123-add-login`, `fix/CT-12-pagination-bug`, `docs/45-update-readme`

## 3. 커밋 메시지 (Conventional Commits)

형식: `<type>(scope)?: <설명>` — 첫 줄(헤더)이 검사 대상이다.

```bash
git add <변경 파일>
git commit -m "feat: 카카오 로그인 추가"
```

예) `feat: 카카오 로그인 추가`, `fix(api): 페이지네이션 오류 수정`, `docs: 컨벤션 문서 추가`

## 4. PR

푸시 후 PR은 `dev` 브랜치로 향하게 만든다. 병합은 Squash and merge, 최소 1명 승인 필요.
PR 작성 절차는 **`dev-pr` 스킬**을 사용한다.

## 참고

- 규약 출처: [docs/conventions/scm-collaboration.md](../../../docs/conventions/scm-collaboration.md)
- 자동 강제(HOOK·SKILL) 개요: [docs/AGENT_GUIDE.md](../../../docs/AGENT_GUIDE.md#강제-규칙-skill--hook)
