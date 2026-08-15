# [설명] 공유 카드 실사용화 (지도 미리보기·네이티브 공유 시트·공유 랜딩 페이지)

## 개요
공유 화면에서 실제 지도 상태를 미리보고, OS 표준 공유 시트로 공유하며, 공유받은 사람이 링크를 눌렀을 때 진행률·DNA·색칠된 지역을 보여주는 공개 랜딩 페이지를 제공한다. [030-share-card](../030-share-card/)의 백엔드 API 위에서 동작하는 프론트엔드 연동 + 공개 웹 랜딩 계층이다. **안드로이드만 대상.**

## 동작 방식
1. 사용자가 앱에서 공유 스타일(`MAP_AND_DNA`/`MAP`/`DNA`)을 고르면, 미리보기 영역에 실제 `ChungbukMap` 위젯(현재 채도 상태)이 표시된다.
2. "공유하기"를 누르면 `share_plus`가 OS 네이티브 공유 시트를 띄우고, 공유 텍스트와 `POST /api/v1/shares`로 발급받은 링크(`{SHARE_BASE_URL}/share/{share_code}`)를 전달한다. 이 링크는 앱 설치 여부와 관계없이 외부 브라우저에서 공개 여행 카드를 여는 URL이며, "링크 복사"는 같은 URL을 클립보드에 복사한다.
3. 외부 사용자가 그 링크를 열면 백엔드의 `GET /share/{share_code}`가 기존 `GET /api/v1/shares/{share_code}`와 동일한 데이터(진행률·DNA·색칠 지역, 공유 스타일별 필터링)를 사람이 읽는 HTML 카드로 렌더링한다. `MAP`/`MAP_AND_DNA` 스타일은 색칠 지역이 0개여도 11개 시·군 지도 그리드를 보여주고, `DNA`/`MAP_AND_DNA` 스타일은 DNA 유형명과 설명을 보여준다. 하단에는 "앱에서 열기"(`colortrip://` 커스텀 스킴, 설치돼 있으면 앱 실행 후 기존 로그인 상태 기반 라우팅에 맡김)와 "앱 다운받기"(Play 스토어 링크, placeholder) 버튼을 제공한다.
4. 앱이 설치돼 있지 않은 상태에서 "앱에서 열기"를 누르면, 핸들러가 없는 커스텀 스킴이라 브라우저가 조용히 무시하고 그 랜딩 페이지에 그대로 머문다(에러 화면 없음).
5. "이미지 저장"을 누르면 현재 공유 스타일의 미리보기 카드가 PNG로 캡처되어 기기 사진 보관함에 저장된다.

```mermaid
flowchart LR
    A[공유 화면: 지도 미리보기] -->|공유 스타일 선택| B[POST /shares]
    B --> C[share_plus 네이티브 공유 시트]
    C --> D[외부 사용자가 링크 클릭]
    D --> E[GET /share/code HTML 랜딩]
    E -->|앱 설치됨| F[앱에서 열기 → 앱 실행]
    E -->|앱 미설치| G[다운받기 CTA / 그대로 랜딩에 머무름]
```

## 주요 구성 요소 / 위치

| 구성 요소 | 역할 | 위치 |
|-----------|------|------|
| 공유 화면 지도 미리보기 | 실제 `ChungbukMap` 위젯을 읽기 전용으로 렌더링 | `frontend/lib/features/home/share_card_screen.dart` |
| 네이티브 공유 시트 | `share_plus`로 OS 표준 공유 시트 호출 | `frontend/lib/features/home/share_card_screen.dart` |
| 이미지 저장 | `RepaintBoundary` 캡처 후 `gal`로 사진 보관함 저장 | `frontend/lib/features/home/share_card_screen.dart` |
| 공유 랜딩 라우트 | 공개 HTML 카드 + "앱에서 열기"/다운로드 버튼 렌더링 | `backend/app/shares/router.py` (`GET /share/{share_code}`) |
| 공유 데이터 조회 | 기존 요약·필터링 로직 재사용 | `backend/app/shares/service.py` (`get_public_share_card`) |
| 앱 실행용 커스텀 스킴 | `colortrip://` intent-filter 등록, 앱 실행만 담당(라우팅 없음) | `frontend/android/app/src/main/AndroidManifest.xml` |

## 설정 / 사용법
* `SHARE_BASE_URL`은 랜딩 페이지의 공개 origin이다. 배포는 `https://${API_DOMAIN}`, 호스트 브라우저를 쓰는 로컬 개발은 `http://localhost:8000`, Android 에뮬레이터는 `http://10.0.2.2:8000`으로 설정한다.
* 앱스토어 CTA 링크는 배포 전까지 placeholder이며, 실제 앱 배포 후 `backend/app/shares/router.py`의 다운로드 URL 상수를 교체해야 한다.

## 예시
`GET /share/AbC12345` → 200 OK, HTML 응답:
* "OO님의 여행 진행률 45%"
* 공개용 충북 지도 그리드(색칠 지역이 0개여도 11개 시·군 표시)
* DNA 유형명과 설명(예: "자연탐험형 여행자")
* "앱에서 열기" 버튼(`colortrip://share/AbC12345`) — 설치돼 있으면 앱 실행, 없으면 페이지에 그대로 머무름
* "앱 다운받기" 버튼(Play 스토어 placeholder)

존재하지 않는 코드로 접속 시 404 안내 페이지.

## 관련 문서
* [030-share-card](../030-share-card/) — 공유 카드 백엔드 API(요약·생성·공개 조회)
* [docs/specs/README.md](../README.md)
