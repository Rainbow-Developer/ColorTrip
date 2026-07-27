# [계획] 다채로울지도 프론트엔드 앱 (Flutter)

> **초기 프로토타입 계획:** 이 문서의 Kakao UI 스텁·백엔드 미연동 결정은 초기 구현 범위의
> 기록이다. 현재 인증 구현과 테스트 결과는
> [035 Kakao 통합 인증](../035-kakao-auth-integration/)을 따른다.

| 항목 | 내용 |
|------|------|
| 기능명 | 다채로울지도 프론트엔드 앱 (Flutter) |
| Spec 폴더 | `docs/specs/000-frontend-app/` |
| 영역 | frontend |
| 작성자 | Bulgogi-Pizza |
| 작성일 | 2026-06-25 |
| 상태 | 초기 프로토타입 계획 / 인증 범위는 035가 대체 |

## 배경 / 목적

"다채로울지도(ColorTrip)"는 **충청북도 11개 시·군을 여행 퀘스트로 탐험하고, 완료한 지역을 지도 위에 색칠해 나가는** 모바일 앱이다. 2026 관광데이터 활용 공모전 제안에 기반한다.

디자인·플로우가 확정된 **인터랙티브 프로토타입**(`다채로울지도.dc.html` — HTML/React 런타임)이 있으나, 이 저장소의 프론트엔드 스택은 [Flutter로 확정](../../conventions/frontend.md)되어 있다. 이 스펙은 프로토타입을 **참고 자료(디자인 SOT)**로 삼아, 컨벤션에 맞는 Flutter 앱으로 `frontend/`에 **처음부터 구현**하는 작업을 정의한다.

## 목표 (Goals)

- `frontend/`에 컨벤션을 따르는 Flutter 앱 골격을 만든다 (라우팅·상태·테마·린트·구조).
- 프로토타입의 **13개 화면을 1:1로 재현**한다: 스플래시 · 회원가입 · 초기설문 · DNA결과 · 홈지도 · 지역퀘스트 · 퀘스트목록 · 퀘스트상세 · 인증(사진/GPS/OX퀴즈) · 타임라인 · 마이 · 내정보수정 · 공유카드 (+ 탈퇴 모달·토스트).
- 프로토타입의 도메인 데이터(11개 시·군 SVG 경로, 5개 퀘스트 유형, 18개 퀘스트, 5개 여행 DNA, 4문항 설문)와 상태 전이를 그대로 옮긴다.
- 지도 색칠(0→1→2+ 단계)·퀘스트 인증·DNA 진단 등 프로토타입의 인터랙션이 동일하게 동작한다.

## 비목표 (Non-Goals)

- **실제 백엔드 연동**: 백엔드가 아직 비어 있으므로 API를 호출하지 않는다. Dio 클라이언트는 구성만 하고 실제 엔드포인트 연결은 후속.
- **실제 카카오 OAuth·JWT**: 키·백엔드 부재로 로그인은 UI 스텁으로 처리한다(아래 의사결정 참고). 실제 [Kakao 직접 구현+JWT](../../conventions/auth-security.md)는 후속.
- **사진 인증의 실제 검증·GPS 실측·외부 관광 데이터(TourAPI)**: 프로토타입과 동일하게 모의(목업) 동작으로 재현한다.
- **테스트 코드**: [코드 품질 컨벤션](../../conventions/code-quality.md)에 따라 초기엔 생략(flutter_test는 추후).
- **푸시(FCM/APNs)·OTA(Shorebird)**: 스택은 컨벤션에 정의돼 있으나 이번 범위 밖.

## 요구사항

**기능 요구사항** — 프로토타입과 동일한 화면·플로우:
- 온보딩: 스플래시 → (카카오 시작) → 회원가입 → 초기 설문(4문항) → DNA 결과 → 홈.
- 홈 지도: 11개 시·군을 진행도에 따라 색칠(0 회색 / 1 라이트그린 #97C459 / 2+ 진그린 #2D6A4F), 통계, 진행 중 지역, 최근 완료. 지역 탭 → 지역 퀘스트.
- 퀘스트: 목록(유형 필터) / 지역별 / 상세 → 인증(사진: 등록→제출→스캔→결과 / GPS: 제출→스캔→결과 / OX퀴즈: 정오답). 완료 시 지도 색칠·타임라인·리워드 반영.
- 타임라인: 완료 퀘스트를 월별 그룹·유형 필터로 표시.
- 마이: 프로필·통계·DNA, 내정보수정(탈퇴 포함)·공유카드(지도/DNA 스타일) 진입.

**비기능 요구사항**:
- 컨벤션 준수: [프론트엔드 스택](../../conventions/frontend.md), [코드 품질](../../conventions/code-quality.md).
- 최소 지원 OS: iOS 16+ / Android 10(API 29)+ ([프론트엔드 스택](../../conventions/frontend.md)).
- 모바일 단일 폼팩터(프로토타입 392×812 기준 반응형).

## 설계 개요 / 접근 방식

프론트엔드 단독 앱이며 백엔드 계약은 이번 범위에 없다. 기술 스택·라우팅·상태관리·폼·지도 방향·린트는 모두 [프론트엔드 스택 컨벤션](../../conventions/frontend.md)·[코드 품질 컨벤션](../../conventions/code-quality.md)을 단일 출처로 따른다(여기서 재서술하지 않음).

**레이어 / 폴더 구조 (feature-first)**

```text
frontend/lib/
  main.dart
  app/        # MaterialApp.router, GoRouter 라우트, ColorTrip 테마(디자인 토큰)
  core/       # Dio 클라이언트(설정만), 상수, 공용 위젯(폰 프레임/상태바·토스트·칩 등)
  data/       # 정적 데이터소스(지역·퀘스트·DNA·설문), 모델, Repository(인터페이스+정적 구현)
  features/   # 화면+상태(Riverpod) 단위
    onboarding/ survey/ home/ quests/ timeline/ profile/
```

**상태**: 앱 전역 진행 상태(완료 퀘스트·지역 진행도·타임라인·DNA·설문 진행)를 Riverpod로 메모리 관리한다. 프로토타입의 `Component` state machine을 Riverpod Notifier로 옮긴다.

**지도**: 프로토타입의 11개 시·군 SVG path를 Flutter `CustomPainter`로 직접 그려 진행도별로 색을 채우고, path 히트테스트로 지역 탭을 처리한다([프론트엔드 스택](../../conventions/frontend.md)의 "이미지 기반 색칠" 방향과 일치).

**데이터**: 프로토타입의 정적 데이터(`QUESTS`/`DNA`/`SURVEY`/지역 경로 등)를 Dart 정적 데이터소스로 옮기고 Repository 인터페이스 뒤에 둔다. 백엔드 준비 시 Repository 구현체만 Dio 기반으로 교체한다.

## 의사결정 (함께 논의 · 근거 필수)

| 결정할 항목 | 선택지 | 제안 / 근거 | 상태 |
|------|--------|------------|------|
| 데이터·상태 소스 | A) 정적 mock+메모리 / B) 정적 mock+로컬 영속 / C) API 계약 먼저 | **A 채택.** 백엔드가 비어 있어 C는 백엔드 설계 의존으로 범위·일정 과다. B의 로컬 영속은 프로토타입(in-memory)을 넘는 기능이라 YAGNI. A는 프로토타입과 동일 범위이며 Repository 인터페이스로 후속 API 교체 seam을 확보 → 오버엔지니어링 없이 호환 | 합의됨 |
| 카카오 로그인 | A) UI 스텁 / B) 실제 Kakao SDK 연동 | **A 채택.** [컨벤션](../../conventions/auth-security.md)은 Kakao 직접 구현+JWT지만 앱 키·백엔드 토큰 교환이 없어 B는 지금 완성 불가. A는 `AuthRepository` 인터페이스로 seam만 남기고 버튼이 다음 화면으로 진행 → 프로토타입 재현 범위와 일치, 후속 연동 시 구현체만 추가 | 합의됨 |
| 지도 렌더링 기법 | A) CustomPainter로 path 직접 / B) flutter_svg | **A 제안.** 지역별 동적 색칠·탭 히트테스트가 핵심인데 B는 per-region 색 변경·히트테스트가 번거롭고 의존성 추가. A는 path 데이터(이미 보유)를 그대로 그리며 색·탭을 자유롭게 제어, 외부 의존성 0 | 제안 |
| 폴더 구조 | A) feature-first / B) layer-first | **A 제안.** 화면(기능) 단위로 응집도 높고 서브에이전트 병렬 구현에 유리. 13화면 규모에서 layer-first는 기능 추적이 어려움 | 제안 |
| 폰트 | Pretendard 번들 / google_fonts | **Pretendard 번들 제안.** 프로토타입이 Pretendard 사용, google_fonts 미제공 폰트라 폰트 파일을 `assets`로 번들 | 제안 |

## 영향 범위

- **신규**: `frontend/` 전체 (Flutter 앱). 커밋 전 검사는 `.pre-commit-config.yaml`에 프론트엔드 `dart format`·`flutter analyze` 훅 추가([코드 품질 컨벤션](../../conventions/code-quality.md)).
- **이 스펙**: `docs/specs/000-frontend-app/`.
- **함께 갱신할 문서** ([AGENT_GUIDE 문서 동기화](../../AGENT_GUIDE.md#문서-동기화-필수) 표 기준, 구현 시점에 갱신):
  - [README.md](../../../README.md): `프로젝트 구조` 트리(frontend/ 채움), `주요 기능과 위치` 표, `패키지 의존성`(프론트엔드), `실행 방법`(프론트엔드), `코드 스타일`(프론트엔드).
- **프로토타입 원본**: 디자인 참고 SOT로 저장소에 보관(위치는 구현 시 확정 — 후보: `docs/specs/000-frontend-app/prototype/`).

## 작업 단계

- [ ] U0 스캐폴드: Flutter SDK 설치, `flutter create`(frontend/), 의존성, 테마/디자인 토큰, GoRouter 라우팅, core 공용 위젯, 정적 데이터·모델·Repository, 공통 Riverpod 상태, pre-commit dart 훅
- [ ] U1 온보딩(스플래시·회원가입) + 초기설문·DNA결과
- [ ] U2 홈 지도(CustomPainter 맵) + 지역 퀘스트
- [ ] U3 퀘스트 목록 + 상세 + 인증 플로우(사진/GPS/OX퀴즈/스캔/결과)
- [ ] U4 타임라인 + 마이 + 내정보수정 + 공유카드
- [ ] 문서 동기화(README), 앱 빌드·실행 검증
- [ ] dev로 PR (dev-pr 스킬)

## 리스크 / 미해결 질문

- Flutter SDK 설치(미설치 상태)로 초기 셋업 시간 소요. macOS 기준 설치.
- 프로토타입의 SVG path 좌표계(viewBox)와 Flutter 캔버스 스케일 매핑 검증 필요.
- 카카오 스텁·정적 데이터는 후속에 실제 연동으로 교체될 임시 구현임을 `implementation.md`에 명시.
