# 팀 컨벤션 (conventions)

ColorTrip 팀이 합의한 **기술 스택·규약·프로세스 결정**을 영역별로 나눠 관리합니다.
한 문서는 한 영역(책임)만 담고, 그 영역의 **결정 사항 표가 단일 출처(SOT)**입니다. README·다른 문서는 여기를 링크로 참조합니다.

새 문서를 추가하거나 갱신할 때는 [`docs/template/conventions.md`](../template/conventions.md) 형식을 따르고, [AGENT_GUIDE 문서 동기화](../AGENT_GUIDE.md#문서-동기화-필수) 규칙을 지킵니다.

## 영역 트리

아래에서 필요한 영역을 타고 들어가세요.

```text
docs/conventions/
├── scm-collaboration.md     # 형상 관리 & 협업 — GitHub·모노레포·브랜치·커밋·PR·Jira
├── backend.md               # 백엔드 스택 — FastAPI·Python 3.13·uv·SQLAlchemy·Alembic
├── frontend.md              # 프론트엔드 스택 — Flutter·Riverpod·GoRouter·Shorebird
├── database.md              # DB & 모델링 — PostgreSQL·snake_case·UUID v7·Soft Delete
├── api-design.md            # API 설계 & 응답 형식 — envelope·/api/v1·페이지네이션
├── auth-security.md         # 인증 & 보안 · 개인정보 — Kakao·JWT·Secret Manager·CORS
├── infra-deploy.md          # 인프라 & 배포 — Docker Compose·GCP·GitHub Actions
├── logging-monitoring.md    # 로깅 & 모니터링 — JSON 로깅·Cloud Logging·Slack 알림
├── code-quality.md          # 코드 품질 & 컨벤션 — Ruff·Pyright·pre-commit(dart format/analyze)
├── docs-tools.md            # 문서화 & 협업 도구 — FigJam·Swagger·Figma·Slack
├── process-milestone.md     # 개발 순서 & 마일스톤 — 진행 순서·일정(8/21)·분담
├── external-apis.md         # 외부 API & 데이터 연동 — TourAPI·Naver·룰 기반 추천
└── release.md               # 앱 출시 & 스토어 — Android 우선·Codemagic·심사 버퍼
```

## 자동 강제되는 규약

일부 규약(보호 브랜치, 커밋 메시지, 브랜치 네이밍)은 **HOOK과 SKILL로 자동 강제**됩니다. 무엇이 어떻게 강제되는지는 [AGENT_GUIDE 강제 규칙](../AGENT_GUIDE.md#강제-규칙-skill--hook)을 참고하세요. 각 규약의 올바른 값은 위 영역 문서가 단일 출처입니다.
