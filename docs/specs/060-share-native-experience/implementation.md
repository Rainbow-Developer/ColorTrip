# [구현 수준] 공유 카드 실사용화 (지도 미리보기·네이티브 공유 시트·공유 랜딩 페이지)

| 항목 | 내용 |
|------|------|
| 상태 | 진행 중 |
| 최종 업데이트 | 2026-08-15 |

## 구현 규모 / 단위 분할

- **규모 판단**: 단위로 나눠 구현 — 근거: 프론트(위젯 교체·공유 시트)와 백엔드(HTML 라우트)가 서로 독립적으로 검증 가능하고, 각 단위가 별도 커밋/검증 지점을 갖는 게 안전하다.
- **구현 단위** (순서대로):
  - [x] 1) 프론트 지도 미리보기 실제 위젯 교체 — 완료 기준: `share_card_screen.dart`에서 실제 `ChungbukMap`이 현재 채도 상태로 렌더링됨(placeholder 텍스트 제거).
  - [x] 2) 프론트 네이티브 공유 시트 + 링크 복사 — 완료 기준: `share_plus`로 실제 OS 공유 시트가 뜨고, 링크 복사가 실제 클립보드에 반영됨(토스트 스텁 제거).
  - [ ] 3) 안드로이드 커스텀 스킴 등록 — 완료 기준: `colortrip://` intent-filter 추가로 앱이 그 스킴 링크로 실행됨. **실제 안드로이드 기기/에뮬레이터에서 아직 검증 안 됨** — intent-filter만 추가한 상태.
  - [x] 4) 백엔드 공유 랜딩 페이지 — 완료 기준: `GET /share/{share_code}`가 실제 데이터로 HTML을 렌더링하고(앱에서 열기/다운받기 버튼 포함), 존재하지 않는 코드는 404 페이지를 반환함.

## 구현된 항목
- [x] 공유 화면 지도 미리보기를 실제 `ChungbukMap` 위젯으로 교체(`share_card_screen.dart`), DNA만 스타일 선택 시 숨김
- [x] `ShareRepository`(`data/repositories/share_repository.dart`) 추가, `POST /shares` 실제 호출로 공유 링크 발급
- [x] `share_plus`로 네이티브 공유 시트 연동, `Clipboard.setData`로 실제 링크 복사(둘 다 로컬 백엔드 대상 Playwright로 검증 — 실제 `POST /api/v1/shares` 201 호출 확인, 클립보드에 실제 URL 기록 확인)
- [x] `AndroidManifest.xml`에 `colortrip://share` 커스텀 스킴 intent-filter 추가(코드 작성만, 실기기 검증은 미완료)
- [x] `GET /share/{share_code}` HTML 랜딩 라우트(`shares/router.py`) — 닉네임·진행률·공개용 지도 그리드·DNA 설명 표시, "앱에서 열기"/"앱 다운받기" 버튼, 존재하지 않는 코드는 404 HTML(로컬에서 200/404 둘 다 curl로 검증). `MAP`/`DNA`/`MAP_AND_DNA` 스타일별 필터링(각각 DNA·지도 영역이 빠지는지)은 `backend/tests/test_shares.py`에 자동화 테스트로 추가해 검증함.
- [x] 공유 URL의 존재하지 않는 고정 도메인을 제거하고 `SHARE_BASE_URL` 설정으로 환경별 공개 origin을 주입
- [x] 공유 스타일 라벨을 한 줄로 표시하고 DNA 아이콘 대신 유형명과 설명을 노출
- [x] 공유 미리보기를 PNG로 캡처해 Android/iOS 사진 보관함에 저장

## 미구현 / 남은 항목
- [ ] 실제 안드로이드 기기 또는 에뮬레이터에서 `colortrip://share/{code}` 링크가 앱을 실행하는지 검증 — 현재는 `AndroidManifest.xml` intent-filter 추가만 하고 실기기 확인 전.

## 알려진 한계 / TODO
* 앱스토어 CTA 링크는 placeholder(`PLAY_STORE_URL = ""`) — 실제 앱 배포 후 `shares/router.py`에서 교체 필요.
* 공유 랜딩은 Flutter의 SVG 지도와 동일한 도형을 복제하지 않고, 백엔드 HTML 전용 11개 시·군 지도 그리드로 표시한다. 색칠 지역이 0개여도 지도 영역은 유지한다.
* "앱에서 열기" 버튼(커스텀 스킴)은 로컬에서 실제 안드로이드 기기/에뮬레이터로 미검증 — intent-filter 설정만 추가한 상태. 다음 APK 빌드·설치 시 실기기 확인 필요.

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-08-02 | 최초 작성 |
| 2026-08-02 | 구현 완료 — 지도 미리보기·공유 API 연동·안드로이드 커스텀 스킴·공유 랜딩 페이지 |
| 2026-08-15 | KAN-072 후속 — 공유 URL 환경설정·스타일/DNA 표현·이미지 저장 보완 |
| 2026-08-15 | KAN-086 후속 — 공유 랜딩에서 0/11 상태에도 지도 그리드와 DNA 설명이 보이도록 보완 |
