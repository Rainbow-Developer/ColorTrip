# [컨벤션] 인증 & 보안 · 개인정보

> **범위**: 소셜 로그인·토큰·토큰 저장·개인정보·시크릿·CORS
> **변경 시**: 이 문서를 단일 출처로 갱신합니다 ([AGENT_GUIDE 문서 동기화](../AGENT_GUIDE.md#문서-동기화-필수) 참고).

## 결정 사항

| 항목 | 결정 | 비고 |
|------|------|------|
| 소셜 로그인 방식 | Kakao 직접 구현 (옵션 A) | |
| 소셜 제공자 범위 | Kakao | |
| 토큰 전략 | Access + Refresh (JWT) | |
| Access token TTL | 15분 | 짧은 TTL, blacklist 미사용 |
| Refresh token TTL | 14일 | DB 저장 hash + rotation |
| Refresh token 저장 | 서버 DB에 hash 저장 | 원문 저장 금지, 로그아웃/탈퇴 시 무효화 |
| 토큰 저장(클라이언트) | flutter_secure_storage | |
| 수집 개인정보 범위 | 이름, 이메일, 생년월일 | |
| 비밀 / 키 관리 | GCP Secret Manager | |
| CORS 정책 | 허용 도메인 화이트리스트 | |
| 로컬 OAuth 검증 | dev-only route | 운영 기본 off |

## 규칙 / 적용

- 인증은 Kakao 직접 구현 + JWT(Access/Refresh)로 처리한다.
- Access token은 15분 TTL로 짧게 유지하고, access token blacklist는 사용하지 않는다.
- Refresh token은 서버 DB에 hash만 저장하고, 재발급 시 rotation한다.
- 로그아웃과 탈퇴는 저장된 refresh token을 `deleted_at`으로 무효화한다.
- 보호 API는 JWT 검증 후 active user(`deleted_at IS NULL`, `anonymized_at IS NULL`)를 DB에서 조회한다.
- 클라이언트 토큰은 flutter_secure_storage에만 저장한다.
- 시크릿은 코드/깃에 두지 않고 GCP Secret Manager를 사용한다(외부 API 키 관리도 동일).
- `local/test` 외 환경은 `JWT_SECRET_KEY`를 반드시 주입해야 하며, 기본 placeholder secret으로는 앱이 시작되지 않아야 한다.
- CORS는 허용 도메인 화이트리스트로 제한한다.
- 실제 Kakao OAuth 브라우저 검증용 dev route는 로컬/테스트 환경에서만 켠다.

## 관련 문서

- [외부 API & 데이터 연동](./external-apis.md)
- [인증/회원 스펙](../specs/005-auth-member/)
