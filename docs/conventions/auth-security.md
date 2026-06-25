# [컨벤션] 인증 & 보안 · 개인정보

> **범위**: 소셜 로그인·토큰·토큰 저장·개인정보·시크릿·CORS
> **변경 시**: 이 문서를 단일 출처로 갱신합니다 ([AGENT_GUIDE 문서 동기화](../AGENT_GUIDE.md#문서-동기화-필수) 참고).

## 결정 사항

| 항목 | 결정 | 비고 |
|------|------|------|
| 소셜 로그인 방식 | Kakao 직접 구현 (옵션 A) | |
| 소셜 제공자 범위 | Kakao | |
| 토큰 전략 | Access + Refresh (JWT) | |
| 토큰 저장(클라이언트) | flutter_secure_storage | |
| 수집 개인정보 범위 | 이름, 이메일, 생년월일 | |
| 비밀 / 키 관리 | GCP Secret Manager | |
| CORS 정책 | 허용 도메인 화이트리스트 | |

## 규칙 / 적용

- 인증은 Kakao 직접 구현 + JWT(Access/Refresh)로 처리한다.
- 클라이언트 토큰은 flutter_secure_storage에만 저장한다.
- 시크릿은 코드/깃에 두지 않고 GCP Secret Manager를 사용한다(외부 API 키 관리도 동일).
- CORS는 허용 도메인 화이트리스트로 제한한다.

## 관련 문서

- [외부 API & 데이터 연동](./external-apis.md)
