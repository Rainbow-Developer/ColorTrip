# [구현 수준] 여행·퀘스트·타임라인 서버 영속화

| 항목 | 내용 |
|------|------|
| 상태 | 진행 중 |
| 최종 업데이트 | 2026-07-28 |

## 구현 규모 / 단위 분할

- **규모 판단**: 단위로 나눠 구현 — migration/API/Flutter 상태·화면/Android 센서가
  순서 의존성을 가지며 각 단위를 독립적으로 회귀 검증할 수 있다.
- **구현 단위**:
  - [x] 1) 작업 격리·기준선 — KAN-53 `b6ad051`에서
    `fix/KAN-55-domain-state-persistence` worktree 생성. backend 133건, Flutter 72건 통과.
  - [x] 2) 문서 우선 — 040 스펙 3종과 관련 스펙·README 갱신, 사용자 승인.
  - [ ] 3) 카탈로그 계약 — `regions.slug`, `quests.client_key`, 220개 snapshot migration,
    정적 Dart 계약 테스트. 빈 DB와 기존 head upgrade 완료.
  - [ ] 4) 백엔드 쓰기 안전성 — 여정 멱등 생성, 선택 일괄 교체, 미션 타입 정렬,
    동시 인증 중복 방지. PostgreSQL 통합 테스트 완료.
  - [ ] 5) Flutter 서버 상태 — Repository·Provider와 여행/퀘스트/지도/타임라인 화면 연결,
    계정 전환과 오류·재시도 위젯 테스트 완료.
  - [ ] 6) 플랫폼 인증 — 사진 업로드와 Android 실제 위치 권한·현재 위치 연동,
    emulator 시나리오 완료.
  - [ ] 7) 최종 검증·문서 완료 — 전체 품질 검사, Android E2E, 보안 검색,
    README·구현 상태·변경 이력 갱신.
  - [ ] 8) 브랜치 마무리 — PR #47 병합 후 KAN-55 커밋만 최신 `dev`에 재배치하고
    재검증한 뒤 Draft PR 생성.

## 구현된 항목

- KAN-55 전용 worktree와 팀 규칙에 맞는 `fix/KAN-55-domain-state-persistence` 브랜치
- 변경 전 기준선: PostgreSQL backend pytest 133건, Flutter test 72건 통과
- 040 계획·설명·구현 수준 문서 초안

## 미구현 / 남은 항목

- 카탈로그 식별자·snapshot migration과 API additive contract
- 여정 멱등성·원자적 선택 변경·동시 인증 중복 방지
- Flutter 여행·진행·지도·타임라인 서버 상태 연동
- 사진/GPS/퀴즈 실제 서버 인증
- 전체 자동 검사, Android E2E, PR #47 이후 재배치와 Draft PR

## 알려진 한계 / TODO

- PR #47이 아직 `dev`에 병합되지 않아 이 브랜치는 KAN-53 위에 쌓여 있다.
- 구현 완료 전까지 기존 Flutter 메모리 상태는 앱 재시작 시 초기화된다.
- 과거에 서버로 전송되지 않은 메모리 기록은 소급 복구하지 않는다.
- Notion API·테이블 명세는 저장소 문서·Swagger 확정 후 수동 역동기화한다.

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-07-28 | KAN-55 worktree·기준선 검증 후 문서 우선 계획 작성 |
| 2026-07-28 | 사용자 승인 후 구현 상태를 진행 중으로 전환 |
