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

## 현재 스펙

| Spec | 기능                                  |
|------|-------------------------------------|
| [000-frontend-app](000-frontend-app/) | Flutter 앱 프로토타입/프론트엔드               |
| [000-quest](000-quest/) | 충북 시·군 퀘스트 조회 기반                    |
| [005-auth-member](005-auth-member/) | Kakao 인증, JWT, 회원 탈퇴/복구             |
| [010-journey](010-journey/) | 여행 생성·관리, DNA 추천, 퀘스트 인증(GPS·사진·퀴즈) |
| [015-database-migration](015-database-migration/) | 핵심 데이터 모델 Alembic 마이그레이션            |
