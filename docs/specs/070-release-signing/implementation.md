# [구현 수준] Android 릴리스 서명 구성

| 항목 | 내용 |
|------|------|
| 상태 | 완료 (저장소 변경분) |
| 최종 업데이트 | 2026-08-06 |
| Jira | [KAN-67](https://rainbowdev00.atlassian.net/browse/KAN-67) |

## 구현 규모 / 단위 분할

- **규모 판단**: **한 번에 구현** — 근거: 변경 파일이 5개(gradle·compose·gitignore·템플릿·문서)로 작고 서로 맞물려 있다. 쪼개면 "서명 분기만 있고 키 고정은 안 된" 중간 상태가 오히려 혼란스럽다.

## 구현된 항목

- [x] `build.gradle.kts` — `key.properties` 있으면 릴리스 키, 없으면 debug 폴백
- [x] 누락 항목 시 `key.properties is missing '<이름>'` 으로 즉시 실패
- [x] debug 폴백 경고 출력 (`println` — `logger.warn`은 flutter가 삼킴)
- [x] `key.properties.example` 템플릿
- [x] `frontend/docker-compose.yml` — `android-config:/root/.android` 볼륨
- [x] 루트 `.gitignore` 안전망 (`*.jks`·`*.keystore`)
- [x] `release.md`·`frontend/README.md` 갱신

## 검증

실제로 확인한 것:

| 검증 | 결과 |
|------|------|
| 키스토어 **없이** 릴리스 빌드 | ✅ 성공 + 경고 출력됨 |
| 키스토어 **있을 때** 릴리스 빌드 | ✅ 임시 키(`CN=SigningPathTest`)로 서명 확인 — APK SHA-1 `500853…`이 생성한 키와 일치 |
| 디버그 키 고정 | ✅ 컨테이너 2회 실행 모두 `E4:F2:49:92:…:46:04` 동일 (수정 전에는 매번 달랐음) |
| `.gitignore` 차단 | ✅ `git check-ignore`로 `test-signing.jks`·`key.properties` 무시 확인 |

## 미구현 / 남은 항목

이 스펙의 **비목표**이며, 담당자가 직접 처리해야 합니다.

- [ ] 릴리스 키스토어 생성 및 안전한 백업 — **분실하면 앱 업데이트 영구 불가**
- [ ] 카카오 개발자 콘솔에 새 디버그 키 해시 등록 (아래 참고)
- [ ] Play Console 앱 서명 키 SHA-1을 카카오에 등록 (Play 배포 시 필수)
- [ ] Codemagic에서 키스토어·비밀번호를 주입해 `key.properties`를 생성하는 스텝

## 알려진 한계 / TODO

- **키 해시가 이번에 한 번 바뀌었다.** `android-config` 볼륨이 새로 생기며 디버그 키스토어가 재생성됐습니다.
  - 이전: `Qgb3/9wJWuXuMTUO8DRf8DQD/Wo=` (무효)
  - 현재: SHA-1 `E4:F2:49:92:62:72:DB:B2:10:DB:75:4F:77:5C:99:28:6B:16:46:04`
  - **이후로는 고정**됩니다.
- 디버그 키 해시는 **개발자·머신마다 다릅니다.** 카카오는 키 해시 복수 등록을 지원하므로 각자 등록하면 됩니다. 팀 공용 debug 키스토어를 커밋하는 방식은 [plan.md](plan.md) 의사결정에서 보류했습니다.
- 릴리스 빌드에서 `key.properties`가 없으면 debug 서명으로 **성공**합니다. 스토어 업로드용 빌드는 CI에서 키스토어 주입을 강제해야 합니다(위 미구현 항목).

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-08-06 | 최초 작성 및 구현. 서명 분기·디버그 키 고정·gitignore 안전망. 양쪽 서명 경로 빌드 검증 완료 |
| 2026-08-13 | CodeRabbit 리뷰 반영 (문서만). keytool 예시에서 `-storepass`·`-keypass` 제거(대화형 입력), 코드 펜스에 `text` 언어 지정, 릴리스 빌드 거부 조건이 카카오 앱 키임을 README·app-run-guide에 명시 |
