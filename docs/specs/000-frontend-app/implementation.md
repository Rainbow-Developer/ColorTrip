# [구현 수준] 다채로울지도 프론트엔드 앱 (Flutter)

| 항목 | 내용 |
|------|------|
| 상태 | 진행 중 (13화면 구현·웹 빌드/렌더 검증·커밋 전 검사 훅 완료, PR 남음) |
| 최종 업데이트 | 2026-06-25 |

## 구현 규모 / 단위 분할

- **규모 판단**: **단위로 나눠 구현**. 근거 — 13개 화면 + 인증 플로우 + 지도 렌더링은 한 번에 다루기 큰 규모이고, 화면군이 서로 독립적이라 feature 단위로 나누면 서브에이전트 병렬 구현이 가능하다([AGENT_GUIDE 작업 워크플로우](../../AGENT_GUIDE.md) · 개인지침 18).
- **구현 단위** (순서대로 — U0는 공통 기반이라 선행, U1~U4는 U0 위에서 병렬 가능):
  - [x] **U0 스캐폴드 (선행)** — Flutter SDK 설치, `flutter create`(frontend/), 의존성(go_router·flutter_riverpod·dio·flutter_form_builder·flutter_secure_storage), 디자인 토큰 테마, GoRouter 라우트·앱 셸, core 공용 위젯(지도·토스트), 정적 데이터·모델·Repository, 공통 Riverpod 상태, pre-commit dart format/analyze 훅. **완료** (lint 0, 빌드 OK).
  - [x] **U1 온보딩+설문** — 스플래시·회원가입·초기설문(4문항)·DNA결과.
  - [x] **U2 홈 지도** — ChungbukMap(11지역 SVG path·히트테스트·진행도 색칠)·통계·진행중·최근완료.
  - [x] **U3 퀘스트(목록·지역·상세·인증)** — 목록(유형 필터)·지역퀘스트·상세·인증(사진/GPS/OX퀴즈/스캔/결과), 완료 시 상태 반영.
  - [x] **U4 타임라인+프로필** — 타임라인(월별/필터)·마이·내정보수정(탈퇴 모달)·공유카드(지도/DNA 스타일).

## 구현된 항목

- [x] U0~U4 전체 13화면 + 앱 셸·라우팅·전역 상태·정적 데이터·지도 위젯
- [x] `flutter analyze` 이슈 0, `flutter build web` 성공
- [x] 웹 렌더 시각 검증(스플래시·홈 지도·퀘스트 목록·퀘스트 상세·마이 — 프로토타입과 일치 확인)
- [x] README 문서 동기화(구조·기능·의존성·실행·코드 스타일)

## 미구현 / 남은 항목

- [ ] dev PR
- [ ] iOS/Android 실기기·시뮬레이터 빌드 검증(현 환경은 Xcode/Android 툴체인 미설치, 웹으로만 검증)

## 알려진 한계 / TODO

- **임시 구현(후속 교체 대상)**: 카카오 로그인은 UI 스텁, 데이터는 정적 mock, 진행 상태는 메모리(앱 재실행 시 초기화), 사진/GPS 인증은 모의 동작. 실제 [Kakao+JWT](../../conventions/auth-security.md)·백엔드 API·[TourAPI](../../conventions/external-apis.md) 연동은 후속 스펙으로 분리.
- **커밋 전 검사 통합 결정**: 프론트엔드 검사를 별도 husky가 아니라 기존 **pre-commit 프레임워크에 `dart format`·`flutter analyze` 훅 추가**로 일원화(공유 git hooks 충돌 회피). 컨벤션도 함께 갱신([코드 품질](../../conventions/code-quality.md)). 단, 이 훅은 flutter/dart가 시스템 PATH(brew `/opt/homebrew/bin` 등)에 있어야 동작한다.
- **프로토타입 버전 차이**: 원본 zip의 `다채로울지도.dc.html`은 travel 화면을 "진행 중/지난 여행"으로 재설계하다 만 미완성본이라, 일관된 `다채로울지도-standalone-src.dc.html`(travel = 유형 필터 퀘스트 목록)을 채택했다. 새 travel 디자인을 원하면 후속 작업으로 분리.
- 테스트는 [코드 품질 컨벤션](../../conventions/code-quality.md)에 따라 초기 생략.

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-06-25 | 최초 작성 (계획) |
| 2026-06-25 | U0~U4 구현 완료, 웹 빌드·렌더 검증, README 동기화 |
| 2026-06-26 | 커밋 전 검사를 pre-commit(dart format/analyze)로 통합, code-quality 컨벤션 갱신 |
