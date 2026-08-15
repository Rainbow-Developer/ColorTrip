# [구현 수준] 개인정보처리방침 페이지

| 항목 | 내용 |
|------|------|
| 상태 | 완료 |
| 최종 업데이트 | 2026-08-13 |

## 구현 규모 / 단위 분할

- **규모 판단**: 한 번에 구현 — 근거: 신규 라우트 1개(정적 HTML) + 프론트 링크 연결 1곳뿐이라
  단위를 나눌 만큼 크지 않다.

## 구현된 항목

- [x] `backend/app/legal/router.py` — `GET /privacy` 정적 HTML 라우트 (TestClient로 200 확인)
- [x] `backend/app/main.py` — 라우터 등록 (`/api/v1` prefix 없이 최상위)
- [x] `frontend/pubspec.yaml` — `url_launcher` 의존성 추가
- [x] `signup_screen.dart` — 개인정보 동의 라벨 옆 "보기" 링크 → 브라우저 오픈
      (`AppConfig.apiBaseUrl` origin 파생, 신규 dart-define 없음)
- [x] `AndroidManifest.xml` — Android 11+ 패키지 가시성용 `<queries>`에 https VIEW intent 추가
- [x] README.md `주요 기능과 위치`, `프론트엔드 주요 의존성` 표 갱신
- [x] `flutter analyze` / `dart format` / `flutter test test/widgets/auth_screens_test.dart`
      (13개 전부 통과, 체크박스 시맨틱스 포함) / backend `ruff check` · `ruff format` ·
      `pyright` 통과

## 미구현 / 남은 항목

- [ ] (코드 범위에서는 없음 — 아래 한계 항목은 사람이 처리해야 하는 후속 작업)

## 알려진 한계 / TODO

- 본문은 법무 검토 전 초안이다. Play Console에 실제 등록하기 전 사람이 검토해야 한다
  (plan.md 리스크 참고). 담당자 연락처는 `rainbow.dev00@gmail.com`으로 반영했다
  (CodeRabbit 리뷰 반영, PR #64).
- URL이 `colortrip.p-e.kr` dev 도메인에 묶여 있다. 다른 도메인으로
  바뀌면 Play Console에 등록한 URL도 함께 갱신해야 한다.
- Android 실기기/에뮬레이터에서 "보기" 링크 탭 → 브라우저 오픈까지의 수동 E2E 확인은 아직
  하지 않았다 (backend 응답과 프론트 analyze/test는 확인됨).

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-08-06 | 최초 작성 (계획) |
| 2026-08-06 | 구현 완료 — backend `GET /privacy`, frontend 링크 연결, 검증 통과 |
| 2026-08-13 | 수집 항목에 프로필 이미지(선택) 반영, 시행일 갱신 ([080](../080-profile-image/), KAN-74) |
| 2026-08-13 | 수집 항목에서 이메일 제거 — 서비스에서 쓰이지 않는 PII라 수집 자체를 폐지했다. 수집 항목이 줄어드는 변경이라 `privacy-v1`은 유지한다 ([인증 & 보안 컨벤션](../../conventions/auth-security.md) SOT 기준) |
