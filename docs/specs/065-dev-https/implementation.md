# [구현 수준] dev 서버 HTTPS 적용

| 항목 | 내용 |
|------|------|
| 상태 | 완료 (PR 머지 대기) |
| 최종 업데이트 | 2026-08-06 |
| Jira | [KAN-64](https://rainbowdev00.atlassian.net/browse/KAN-64) |
| PR | [#61](https://github.com/Rainbow-Developer/ColorTrip/pull/61) |

## 구현 규모 / 단위 분할

- **규모 판단**: **한 번에 구현** — 근거: 변경 파일이 배포 스택 4개(Caddyfile·compose·deploy.sh·workflow)와 문서로 한정되고, 서로 강하게 맞물려 있어 쪼개면 중간 상태가 배포 불가가 된다. 애플리케이션 코드 변경은 없다.

## 구현된 항목

- [x] GCP Secret Manager 시크릿 5종 생성 (`kakao-rest-api-key`, `kakao-client-secret`, `kakao-redirect-uri`, `jwt-secret-key`, `tour-api-key`)
- [x] GitHub 저장소 variable `KAKAO_APP_ID` 등록 — 배포 8연속 실패의 직접 원인 해소
- [x] 스펙 문서 3종 작성
- [x] `deploy/Caddyfile` 작성
- [x] `deploy/docker-compose.yml` — caddy 서비스 추가, api 포트 매핑 제거, 인증서 볼륨
- [x] `deploy/deploy.sh` — `API_DOMAIN` 필수화, health check 대상 변경
- [x] `.github/workflows/deploy-dev.yml` — Caddyfile 전송, `API_DOMAIN` 주입
- [x] `deploy/.env.example` · `deploy/README.md` 갱신

- [x] GitHub 저장소 variable `API_DOMAIN` 등록
- [x] dev 배포 실행 및 실검증 — `/health` 200, Let's Encrypt 인증서 유효(만료 2026-11-04), HTTP→HTTPS 308, 라우트 29개(이전 4개)
- [x] 릴리스 APK를 https 주소로 빌드 → 에뮬레이터 설치·기동, cleartext/TLS 오류 없음
- [x] 에뮬레이터 Chrome에서 인증서 경고 없이 200 — Android 신뢰 저장소가 Let's Encrypt 루트를 이미 신뢰
- [x] `infra-deploy.md` · `gcp-access.md` · `app-run-guide.md` · `frontend/README.md` · `deploy/README.md` 갱신

- [x] PR [#61](https://github.com/Rainbow-Developer/ColorTrip/pull/61) 머지 — 머지 후 dev 푸시 배포 성공(포트 충돌 해소)
- [x] `README.md` 실행 파이프라인에 Caddy 반영
- [x] CodeRabbit 리뷰 7건 반영

## 미구현 / 남은 항목

- [ ] 카카오 로그인 후 화면까지 실조작 검증 (계정 자격증명 필요 — 사람이 직접)
- [x] 실제 연결 도메인 `colortrip.p-e.kr`로 `API_DOMAIN` 기준 교체

## 알려진 한계 / TODO

- **DNS 설정 의존성**: `colortrip.p-e.kr`가 고정 퍼블릭 IP `34.64.226.70`을 가리켜야 한다. 교체 시 `API_DOMAIN` variable 값만 바꾸면 되도록 설계했다.
- **`docs/app-run-guide.md`가 낡았다.** 하드코딩 Bearer 토큰 기준으로 쓰여 있는데 실제 코드는 카카오 로그인으로 전환됐다(`dio_client.dart`에 토큰 없음). 이 스펙 범위에서 함께 정리한다.
- **prod 환경은 미적용.** 현재 배포 파이프라인이 dev 단일 환경만 다룬다.
- 릴리스 APK는 여전히 **debug 키로 서명**된다 — 스토어 업로드 불가. [release.md](../../conventions/release.md) 경로 별개.

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-08-06 | 최초 작성. GCP 시크릿·GitHub variable 등록 완료, 배포 스택 HTTPS 전환 구현 |
| 2026-08-06 | dev 배포·HTTPS 실검증 완료. dev의 KAN-65(#60)와 CORS 수정이 겹쳐 병합 정리, PR #61 생성 |
| 2026-08-06 | PR #61 머지. CodeRabbit 리뷰 7건 반영 — 호스트명 DNS 라벨 검증, probe 타임아웃·엄격한 200 비교, 외부 HTTPS probe 추가(공개 DNS·방화벽 검증), Caddy 이미지 digest 고정, 문서 정합 |
