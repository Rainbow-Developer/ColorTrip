# [구현 수준] 프로필 이미지

| 항목 | 내용 |
|------|------|
| 상태 | 완료 (에뮬레이터 수동 E2E 미실시) |
| 최종 업데이트 | 2026-08-13 |

## 구현 규모 / 단위 분할

- **규모 판단**: 한 번에 구현 — 근거: DB 마이그레이션이 없고(`users.profile_image` 컬럼이 이미 존재), 응답 스키마도 바뀌지 않는다. 백엔드 endpoint 2개와 프론트 화면 3개가 하나의 사용자 흐름(등록→표시→교체·제거)을 이루므로 쪼개면 어느 단위도 단독으로 검증할 수 없다 — 백엔드만 먼저 넣으면 호출부가 없고, 프론트만 넣으면 저장할 곳이 없다. 총 변경 규모도 신규 파일 3개 + 수정 10여 개 수준이라 한 PR로 리뷰 가능하다.
- **구현 단위**: 분할하지 않음. 다만 아래 순서를 지킨다 — 공용 헬퍼 추출(기존 `/uploads/photo` 회귀 없음을 `test_uploads.py`로 먼저 확인) → 신규 endpoint → 프론트 공용 조각 추출 → 화면 반영.

## 구현된 항목

### 백엔드

- [x] `uploads/service.py` — `ALLOWED_IMAGE_TYPES`, `StoredImage`, `store_uploaded_image()`, `commit_or_discard_image()` 추출
- [x] `uploads/router.py` — 헬퍼 사용하도록 축소. `photos/` prefix·응답 형태 불변(기존 테스트 4건 그대로 통과)
- [x] `auth/service.py` — `replace_profile_image()`, `remove_profile_image()`
- [x] `auth/router.py` — `POST`·`DELETE /users/me/profile-image` (`ActiveUser`, 200, `Envelope[UserProfile]`)
- [x] `shares/schemas.py`·`shares/service.py` — 미사용 `owner_profile_image`·`profile_image` 제거 ([plan.md](./plan.md) 의사결정 5)
- [x] `legal/router.py` — 개인정보처리방침 수집 항목 표 갱신, 시행일 `2026-08-13`
- [x] `tests/test_profile_image.py` 11건 — 온보딩 전 업로드 / 카카오 초기값 교체 / 형식·용량·빈 파일 거부 / 미인증(업로드·삭제) / DELETE 멱등성 / 아바타 URL의 퀘스트 인증 재사용 차단 / 탈퇴 시 제거
- [x] `tests/test_uploads.py` — 리팩터링 회귀 가드(`uploaded_photos` 행 생성 확인) 1건 추가

### 프론트엔드

- [x] `core/network/dio_client.dart` — `resolveUploadUrlProvider`
- [x] `core/image_picking.dart` — 피킹 순수 로직 추출(`PickedImage`, `PickImageException`, `pickImageBytes`, `mimeTypeForFileName`)
- [x] `core/widgets/profile_image_picker.dart` — 공용 아바타 피커(카메라/갤러리/기본 이미지로 변경, `pickImage` 테스트 seam)
- [x] `data/repositories/auth_repository.dart` — `uploadProfileImage()`, `removeProfileImage()`
- [x] `state/auth_controller.dart` — `_applyProfileImageChange()`로 두 메서드 연결
- [x] `features/onboarding/signup_screen.dart` — 닉네임 위에 피커 + `프로필 이미지 (선택)` 캡션
- [x] `features/profile/edit_profile_screen.dart` — 하드코딩 👤 컨테이너를 피커로 교체
- [x] `features/profile/profile_screen.dart` — 빈 `CircleAvatar`를 `AppNetworkImage`로 교체
- [x] `features/quests/quest_verify_screen.dart` · `quest_detail_screen.dart` — 추출한 공용 조각 사용하도록 리팩터링
- [x] `AuthRepository` fake 3곳 갱신
- [x] 신규/추가 테스트 — `test/core/upload_url_test.dart` 5건, repository 2건, controller 3건, 위젯 5건

### 문서

- [x] `docs/conventions/auth-security.md` — 수집 PII 범위(SOT)와 `ActiveUser` 예외
- [x] `docs/specs/035-kakao-auth-integration/` — PII 한정 서술·권한 사다리 현행화
- [x] `docs/specs/075-privacy-policy-page/` — 수집 항목 표 반영
- [x] `README.md`, `docs/specs/README.md`

### 검증

- [x] backend `ruff check` · `ruff format` · `pyright` 0 errors · `pytest` **196 passed**
- [x] frontend `flutter analyze` 0 issues · `flutter test` **122 passed**

> 기준선 확인: `origin/dev`를 별도 worktree로 받아 같은 명령을 돌린 결과 backend 184 passed / 5 failed, frontend 107 passed / 1 failed였다. 실패 5건(`test_deploy_migration` 2건, `test_domain_catalog_contract` 1건, `test_map_flow` 2건)과 frontend 1건(`kan28_features_test`)은 이 브랜치 이전부터 실패하던 것으로, 이번 변경으로 새로 깨진 테스트는 없다. `test_map_flow` 2건은 사진 소유권 도입 후 fixture에 없는 `/uploads/x.jpg`를 쓰는 낡은 테스트다 — 별도 처리 필요.

기능과 무관하게 **이미 존재하는 기반**은 다음과 같다. 이번 작업에서 새로 만들지 않는다.

- `users.profile_image` 컬럼 ([015-database-migration](../015-database-migration/), revision `a4f2c8d1e9b0`)
- `UserProfile` 응답 스키마의 `profile_image` 필드 및 Flutter `UserProfile.profileImage` 파싱
- 카카오 최초 로그인 시 카카오 프로필 사진 URL을 초기값으로 저장하는 경로
- 탈퇴 시 `profile_image`를 비우는 익명화 로직과 DB 트리거 (revision `7f2a1c9d4e6b`)
- `PhotoStorage`(GCS/로컬) 추상화와 업로드 검증·보상 삭제 로직 ([010-journey](../010-journey/))
- `AppNetworkImage` 공용 위젯과 `image_picker` 의존성

## 미구현 / 남은 항목

- [ ] **Android 에뮬레이터 수동 E2E** — 카카오 로그인 → 회원가입 화면에 카카오 이미지가 기본 표시되는지 → 갤러리에서 교체 → 기본 이미지로 변경 → 온보딩 완료 → 마이·내 정보 수정 반영 → 탈퇴 후 재가입 시 초기화. `image_picker` 플랫폼 채널이 필요한 구간이라 자동 테스트로 대체할 수 없다.

## 알려진 한계 / TODO

- **스토리지 객체를 정리하지 않는다** ([plan.md](./plan.md) 의사결정 2). 이미지를 교체·삭제하거나 탈퇴해도 DB의 `profile_image`만 바뀌고 저장된 객체는 남는다. 개인정보처리방침의 "탈퇴 시 지체 없이 파기" 문구와 긴장 관계에 있으므로, GCS lifecycle 규칙이나 정리 잡 도입을 후속 과제로 남긴다.
- **가입 중단 시 고아 객체가 생긴다.** 선택 즉시 업로드 방식이라 온보딩을 끝내지 않고 이탈해도 객체는 저장된다. 위 항목과 같은 부류로 취급한다.
- **이미지 원본이 URL만 알면 공개 접근된다.** GCS 공개 읽기 버킷 전제([010-journey](../010-journey/) 의사결정 3)를 그대로 따른다. 비공개 버킷 + signed URL 전환은 이 스펙 범위 밖이다.
- **업로드 중 회원가입 폼 전체가 잠긴다.** `auth.isBusy`가 모든 입력과 `다음` 버튼을 함께 비활성화한다. 체감이 나쁘면 이미지 업로드용 busy 상태를 분리해야 한다.
- **카메라·갤러리 실동작은 자동 테스트 범위 밖이다.** `image_picker` 플랫폼 채널이 필요해 위젯 테스트에서는 주입 seam으로 대체하고, 실제 동작은 에뮬레이터 수동 확인에 의존한다(퀘스트 사진 인증과 동일).
- **이미지 편집 기능이 없다.** 크롭·회전 없이 원본을 축소만 해서 올리므로, 정사각형이 아닌 사진은 아바타에서 가운데 기준으로 잘려 보인다.

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-08-13 | 최초 작성 (KAN-74) |
| 2026-08-13 | 구현 완료 — 백엔드 endpoint 2종, 프론트 공용 조각 3개와 화면 3곳, 공유 응답의 미사용 아바타 필드 제거, 문서 동기화. 에뮬레이터 수동 E2E만 남음 |
