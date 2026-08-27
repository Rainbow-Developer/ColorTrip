# 원스토어 등록 자료 (다채로울지도)

> 공공데이터 활용 심사 제출용 "스토어 등록 완료 링크" 확보 목적. Google Play는 개인 신규
> 계정의 비공개 테스트 12명×14일 요건 때문에 공개 링크 확보까지 3주 안팎이 걸려,
> 심사가 1~2시간인 원스토어를 우선 등록한다. Play 경로는 [play-data-safety.md](play-data-safety.md) 참고.

## 1. 사전 준비 (사람이 해야 하는 것)

- [ ] **원스토어 개발자센터 가입** — https://dev.onestore.co.kr (개인 또는 사업자. 사업자는 사업자등록증 필요)
- [ ] **릴리스 키스토어 확보** — Play 내부 테스트에 업로드할 때 쓴 `colortrip-release.jks` + `key.properties`를 빌드할 머신의 `frontend/android/`에 배치 (커밋 금지, [key.properties.example](../../frontend/android/key.properties.example) 참고)
- [ ] **스크린샷 2~8장** — 실기기/에뮬레이터에서 캡처 (홈 지도·퀘스트 목록·인증·타임라인·공유 카드 추천). 등록 화면에 표시되는 해상도 권장사항 확인
- [ ] 지원 연락처(이메일·전화) — 스토어 상품 페이지에 노출됨

## 2. 빌드 (AAB 또는 APK 모두 가능)

```bash
docker compose -f frontend/docker-compose.yml run --rm -u 0:0 -e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0=* frontend bash -c "flutter pub get && flutter build apk --release --dart-define=KAKAO_NATIVE_APP_KEY=YOUR_NATIVE_APP_KEY --dart-define=API_BASE_URL=https://colortrip.p-e.kr/api/v1"
```

- `YOUR_NATIVE_APP_KEY`는 실제 Kakao 네이티브 앱 키로 바꿔서 실행한다(값은 `backend/.env`).
- `--dart-define` 2개 필수 — `KAKAO_NATIVE_APP_KEY`가 없으면 release Gradle 빌드가 실패하고,
  `API_BASE_URL`이 없으면 빌드는 되지만 앱 실행 시 설정 오류 화면(ConfigErrorApp)이 뜬다.
- API는 반드시 HTTPS — 릴리스 빌드는 평문 HTTP 차단([065-dev-https](../specs/065-dev-https/)).
- `key.properties` 없으면 debug 키 폴백 + 경고 → 스토어 업로드 불가.

## 3. 카카오 키 해시 — 서명 옵션에 따라 달라짐

원스토어 앱 등록의 "서명키 옵션"에서:

| 선택 | 카카오에 등록할 해시 |
|------|---------------------|
| **원스토어 앱 서명 사용(원스토어가 키 관리)** | 원스토어가 **재서명**하므로 개발자센터에 표시되는 **원스토어 서명 인증서의 SHA-1**을 해시로 변환해 등록 |
| 자체 서명 그대로 배포 | 업로드(릴리스) 키 해시 등록 |

SHA-1 → 카카오 해시 변환:

```bash
echo "<SHA-1 hex>" | tr -d ':' | xxd -r -p | openssl base64
```

두 경우 모두 **업로드 키 해시도 함께 등록**해두면 직접 설치 검증이 편하다(카카오는 복수 등록 지원).
Play 때와 같은 함정: 등록 누락 시 스토어로 받은 앱만 `KOE009 / invalid android_key_hash`로 로그인 실패.

## 4. 스토어 등록 정보 초안

| 항목 | 값 |
|------|----|
| 앱 이름 | 다채로울지도 |
| 패키지명 | `com.rainbowdev.colortrip` (KAN-109에서 변경 — Kakao Developers의 Android 플랫폼 패키지명도 갱신 필수) |
| 카테고리 | 여행 (또는 라이프스타일) |
| 가격 | 무료, 인앱결제 없음 (→ 원스토어 IAP SDK 의무 없음) |
| 등급 | 전체이용가 예상 (등급분류 설문 답변) |
| 개인정보처리방침 URL | https://colortrip.p-e.kr/privacy |
| 아이콘 원본 | `frontend/assets/icon/app_icon.png` (등록 규격에 맞게 리사이즈) |

**한 줄 소개(초안)**

> 충북 11개 시·군을 퀘스트로 여행하고, 다녀온 만큼 지도를 색칠하는 여행 기록 앱

**상세 설명(초안)**

> 다채로울지도는 충청북도 11개 시·군을 여행 퀘스트로 탐험하는 앱입니다.
>
> - 🧬 여행 DNA 진단 — 간단한 설문으로 나의 여행 성향(자연탐험·미식·역사문화·액티비티·힐링)을 진단하고 맞춤 퀘스트를 추천받아요.
> - 🗺️ 지도 색칠 — 퀘스트를 완료할수록 지역이 진하게 칠해지는 수집형 여행 지도.
> - 📸 퀘스트 인증 — 사진·GPS·OX퀴즈로 실제 방문을 인증해요. 위치 좌표는 기기 밖으로 전송하지 않습니다.
> - 🎪 지역 행사·축제 — 진행 중인 지역 축제와 근처 추천 퀘스트를 한눈에.
> - 📅 여행 타임라인 — 완료한 퀘스트를 월별·지역별로 모아보고, 색칠한 지도를 공유 카드로 자랑하세요.
>
> 카카오 계정으로 간편하게 시작할 수 있습니다.

## 5. 심사·제출

1. 개발자센터 → 앱 등록 → 위 자료 입력 + 빌드 업로드 → 심사 신청 (보통 1~2시간)
2. 판매(배포) 시작 후 **상품 페이지 URL**을 공공데이터 심사 서식에 제출
3. 테스트 계정 항목은 **"SNS 연동 로그인"** 선택 (카카오 로그인만으로 이용 가능)
   - 단, **카카오 개발자 콘솔의 앱이 "서비스 중(라이브)" 상태**여야 임의 계정 로그인 가능 — 개발 중 상태면 팀 멤버 계정만 로그인됨. 제출 전 반드시 전환·확인.

## 6. 제출 전 확인

- [ ] 스토어에서 받은 APK로 카카오 로그인 성공 (키 해시 검증)
- [ ] dev 서버(https://colortrip.p-e.kr) 기동 상태 — 심사자가 접속함
- [ ] `/privacy` 페이지 접속 확인
- [ ] Play와 달리 원스토어에도 Data Safety 유사 항목(접근 권한 고지 등)이 있으면 [play-data-safety.md](play-data-safety.md) 답변 재사용
