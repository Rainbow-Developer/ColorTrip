# 기능 스펙 (specs)

추가될 예정이거나 진행 중인 기능의 **계획·설명·구현 수준**을 기능 단위 폴더로 관리합니다.

- 폴더명: `{NNN}-{feature-name}` — `{NNN}`은 **5의 배수 prefix**(`000`, `005`, `010`, `015` …)로, 기존 최대 prefix + 5로 매깁니다. (사이에 끼워 넣을 여지를 두기 위함)
- 각 폴더에는 `plan.md`, `description.md`, `implementation.md` **3개 파일이 반드시** 있어야 하며, 반드시 [`docs/template/specs/`](../template/specs/)의 공통 템플릿을 복사해서 작성합니다.

```text
docs/specs/
├── 000-{feature-name}/
│   ├── plan.md
│   ├── description.md
│   └── implementation.md
└── 005-{feature-name}/
    ├── plan.md
    ├── description.md
    └── implementation.md
```

자세한 작성 규칙은 [docs/AGENT_GUIDE.md의 '기능 스펙'](../AGENT_GUIDE.md#기능-스펙-docsspecs)을 참고하세요.
