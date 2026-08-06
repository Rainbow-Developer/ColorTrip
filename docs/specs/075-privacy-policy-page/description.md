# [설명] 개인정보처리방침 페이지

## 개요

Google Play 등록에 필요한 개인정보처리방침을 공개 URL(`GET /privacy`)로 제공하는 정적
페이지다. backend가 인라인 HTML로 렌더링해 응답하며, 앱 회원가입 화면의 개인정보 동의
체크박스에서 외부 브라우저로 열 수 있다.

## 동작 방식

1. 사용자가 회원가입 화면에서 "[필수] 개인정보 수집 동의" 라벨을 탭한다.
2. 앱이 `AppConfig.apiBaseUrl`의 origin(`scheme://host[:port]`)에 `/privacy`를 붙여 URL을
   계산한다 (예: `API_BASE_URL=https://34-64-226-70.sslip.io/api/v1` → `https://34-64-226-70.sslip.io/privacy`).
3. `url_launcher`로 외부 브라우저를 열어 그 URL로 이동시킨다.
4. backend `GET /privacy`가 인증 없이 정적 HTML을 반환한다. 본문 하단에 현재 동의 버전
   (`privacy-v1`)을 표시한다.

Play 심사 봇이나 사용자가 이 URL을 직접 열어도 동일하게 동작한다 — 앱 설치·로그인이 필요
없다.

## 주요 구성 요소 / 위치

| 구성 요소 | 역할 | 위치 |
|-----------|------|------|
| `legal_router` | `GET /privacy` 정적 HTML 응답, `/api/v1` prefix 없이 최상위 등록 | `backend/app/legal/router.py` |
| 라우터 등록 | `app.include_router(legal_router)` | `backend/app/main.py` |
| 동의 버전 상수 | 페이지에 표시할 `PRIVACY_CONSENT_VERSION = "privacy-v1"` (SOT, 재사용만 함) | `backend/app/auth/service.py` |
| 링크 연결 | 개인정보 동의 라벨 탭 → `url_launcher`로 오픈 | `frontend/lib/features/onboarding/signup_screen.dart` |
| URL 계산 | `apiBaseUrl` origin 파생 | `frontend/lib/core/config/app_config.dart` (기존 값 재사용, 신규 코드 최소) |

## 설정 / 사용법

- 별도 환경변수·dart-define 없음 — 기존 `API_BASE_URL` 빌드값을 그대로 사용한다.
- 로컬 확인: backend 기동 후 `curl http://localhost:8000/privacy` (또는 dev 서버
  `https://34-64-226-70.sslip.io/privacy`).

## 예시

```
GET https://34-64-226-70.sslip.io/privacy

200 OK
Content-Type: text/html

<!doctype html>
... 개인정보처리방침 본문 ...
<footer>버전: privacy-v1</footer>
```

## 관련 문서

- [plan.md](plan.md) — 의사결정 근거
- [docs/conventions/auth-security.md](../../conventions/auth-security.md) — 수집 개인정보
  범위·동의 버전 SOT
- [060-share-native-experience](../060-share-native-experience/description.md) — 이번에 재사용한
  공개 랜딩 라우터 패턴의 원본
- [065-dev-https](../065-dev-https/description.md) — 이 페이지가 노출되는 HTTPS 도메인
