# [구현 수준] 여행·퀘스트·타임라인 서버 영속화

| 항목 | 내용 |
|------|------|
| 상태 | 구현·검증 완료 / 브랜치 마무리 대기 |
| 최종 업데이트 | 2026-07-29 |

## 구현 규모 / 단위 분할

- **규모 판단**: 단위로 나눠 구현 — migration/API/Flutter 상태·화면/Android 센서가
  순서 의존성을 가지며 각 단위를 독립적으로 회귀 검증할 수 있다.
- **구현 단위**:
  - [x] 1) 작업 격리·기준선 — KAN-53 `b6ad051`에서
    `fix/KAN-55-domain-state-persistence` worktree 생성. backend 133건, Flutter 72건 통과.
  - [x] 2) 문서 우선 — 040 스펙 3종과 관련 스펙·README 갱신, 사용자 승인.
  - [x] 3) 카탈로그 계약 — `regions.slug`, `quests.client_key`, 220개 snapshot migration,
    정적 Dart 계약 테스트. 빈 DB와 기존 head upgrade 완료.
  - [x] 4) 백엔드 쓰기 안전성 — 여정 멱등 생성, 선택 일괄 교체, 미션 타입 정렬,
    동시 인증 중복 방지. PostgreSQL 통합 테스트 완료.
  - [x] 5) Flutter 서버 상태 — Repository·Provider와 여행/퀘스트/지도/타임라인 화면 연결,
    계정 전환과 오류·재시도 위젯 테스트 완료.
  - [x] 6) 플랫폼 인증 — 사진 업로드와 Android 실제 위치 권한·현재 위치 연동,
    debug APK 설치와 실제 Kakao Account 로그인·온보딩 완료.
  - [x] 7) 최종 검증·문서 완료 — 전체 품질 검사, Android E2E, 보안 검색,
    README·구현 상태·변경 이력 갱신.
  - [ ] 8) 브랜치 마무리 — 닫힌 미병합 PR #47을 대체할 KAN-53 통합 경로가
    확정되면 KAN-55 커밋만 최신 `dev`에 재배치하고 재검증한 뒤 Draft PR 생성.

## 구현된 항목

- `regions.slug`·`quests.client_key` 고유 stable key와 11개 지역·220개 퀘스트
  불변 migration snapshot. 기존 동일 데이터는 재사용하고 모호한 충돌은 migration을 중단한다.
- 사용자별 `client_request_id`를 이용한 여정 멱등 생성, 여정 퀘스트 최종 집합의 원자적
  교체, row lock과 PostgreSQL upsert를 이용한 동시 인증 중복 방지
- stable key가 없는 기존 TourAPI 지역·퀘스트도 조회 API에서 계속 반환하고,
  Flutter 매핑에서만 제외해 additive 하위 호환 유지
- 여정 목록의 `quest_client_keys` bulk 응답으로 앱 부팅 시 여정별 상세 N+1 제거,
  여행 카드에서 선택한 `journeyId`를 지역·선택·인증 화면까지 전달
- `photo`·`gps`·`gps_photo`·`quiz`별 서버 검증과 완료 트랜잭션의 지도·타임라인 반영
- 타임라인 응답의 `quest_id`·`quest_client_key`·`photo_url` 복원 식별자
- 제약 추가 전에 기존 중복 완료 타임라인을 가장 이른 이벤트 하나로 수렴시켜
  기존 dev DB migration 실패 방지
- Flutter `DioDomainRepository`·`DomainController`·`DomainStateGate`, 인증 수명주기와
  도메인 상태 초기화, 여행·퀘스트·지도·타임라인 화면 서버 연동
- 사진 multipart 업로드와 Android/iOS 위치 권한 설정, 실제 현재 위치 기반 GPS 인증
- 백엔드 KAN-55 집중 테스트·전체 149건, Flutter 전체 테스트 82건,
  Ruff·Pyright·Dart format·Flutter analyze와 Android debug build 통과
- 격리 PostgreSQL·로컬 FastAPI·Android emulator에서 실제 Kakao Account 로그인,
  프로필/필수 동의 저장, 여행 DNA 제출, 여행 생성, OX 퀴즈 완료를 검증
- 여행 생성 요청에서 만료된 access token의 401 후 refresh rotation 200과 원 요청
  1회 재시도 201을 실제 흐름으로 확인
- 앱 강제 종료·재실행 후 `GET /users/me`, 지역·퀘스트·여정·진행도·지도·타임라인
  재조회와 여행 카드·단양 지도 색상·완료 퀘스트 타임라인 복원을 확인
- 빈 로컬 DB에서는 `uv run python -m app.trip_dna.seed`를 명시적으로 실행해야 하며,
  공식 시드 적용 전 빈 설문 상태와 적용 후 4개 문항 조회를 모두 확인

## 미구현 / 남은 항목

- KAN-53 통합 경로 확정 후 최신 `dev` 재배치·재검증·Draft PR

## 알려진 한계 / TODO

- PR #47은 병합되지 않은 채 닫혔고 대체 PR이 없어, 이 브랜치는 KAN-53 위에
  쌓인 상태로 브랜치 마무리를 대기한다.
- `ProgressState`는 기존 화면 호환 projection으로 남아 있지만 앱 부팅과 서버 쓰기
  성공 후 `DomainController`의 최신 snapshot으로 다시 채워진다.
- 과거에 서버로 전송되지 않은 메모리 기록은 소급 복구하지 않는다.
- Notion API·테이블 명세는 저장소 문서·Swagger 확정 후 수동 역동기화한다.

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-07-28 | KAN-55 worktree·기준선 검증 후 문서 우선 계획 작성 |
| 2026-07-28 | 사용자 승인 후 구현 상태를 진행 중으로 전환 |
| 2026-07-28 | stable catalog·멱등 여정·동시 인증 안전성·Flutter 서버 상태·실제 위치/사진 연동 완료. 실제 계정 재시작 복원 E2E와 브랜치 마무리는 진행 중 |
| 2026-07-29 | 실제 Kakao 계정 Android E2E에서 온보딩·refresh rotation·여행/퀴즈 완료와 강제 재시작 후 여행·지도·타임라인 복원까지 확인. 구현·검증 완료, 브랜치 마무리만 대기 |
