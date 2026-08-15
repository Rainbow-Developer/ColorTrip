# Play Console — Data Safety 설문 답변 (초안)

> Play Console에 실제 입력할 때 참고용. 코드·기존 법률 검토 문서 기준으로 작성했으며,
> 법적 정확성은 최종적으로 사람이 확인해야 한다 (아래 "확인 필요" 표시 항목 특히).
> 근거: [050-quest-verification/location-law-review.md](../specs/050-quest-verification/location-law-review.md),
> [075-privacy-policy-page](../specs/075-privacy-policy-page/description.md)

## 1. 앱이 데이터를 수집·공유하나요?

**예**

## 2. 데이터 유형별 답변

### 위치정보 (Location)

| 항목 | 답변 |
|---|---|
| 수집 여부 | **수집 안 함으로 신고 권장** |
| 근거 | 퀘스트 위치 인증은 GPS 좌표를 하버사인 거리 계산까지 전부 단말기 안에서 수행하고, 어떤 서버로도 좌표를 전송하지 않는다 (`geolocator` 결과값이 dio 요청 payload에 실리지 않음 — 코드 리뷰로 확인된 불변식). Play의 "수집" 정의는 기기 밖으로의 전송을 기준으로 한다. |
| ⚠️ 확인 필요 | Play가 `ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION` 권한 자체만으로 위치 데이터 유형 신고를 요구하는지는 리뷰 시점에 달라질 수 있음. 리뷰에서 문제 제기되면 위 근거(단말 내 처리, 좌표 미전송)를 소명 자료로 제시. |

### 사진/동영상 (Photos and videos)

| 항목 | 답변 |
|---|---|
| 수집 여부 | **수집함** |
| 세부 목적 1 — 프로필 사진 | 앱 기능(계정 관리). 저장됨(GCS/로컬 업로드 스토리지). 사용자가 언제든 교체·삭제 가능 (`backend/app/uploads/`, `auth/service.py`) |
| 세부 목적 2 — 퀘스트 인증 사진 | 앱 기능. **AI 판정 후 즉시 폐기, 서버에 저장하지 않음** (`docs/specs/050-quest-verification/description.md`: "사진은 판정 후 저장하지 않는다") |
| 세부 목적 3 — 완료 기록(선택) | 사용자가 원할 경우에만 타임라인 기록용으로 사진 사본이 저장됨 (`quests/service.py`의 `photo_url`) |
| 필수 여부 | 선택 (사진 인증을 쓸 때만 카메라 권한 요청, 앱 자체 이용엔 불필요) |
| 전송 중 암호화 | 예 (HTTPS) |
| 삭제 요청 가능 | 예 (회원탈퇴 시 전체 삭제, 프로필 사진은 개별 삭제 가능) |
| 제3자 처리 | Google Gemini API로 인증 사진이 전송되어 AI 판정에 쓰임 — **서비스 제공자로서의 처리**로 분류 권장(직접적 제3자 공유가 아님). 이미지 자체는 Gemini 판정 후 어느 쪽에도 저장되지 않음 |

### 개인 정보 (Personal info)

| 항목 | 답변 |
|---|---|
| 이름 | 수집함 — 닉네임, 계정 관리 목적, 필수 |
| 이메일 주소 | **수집하지 않음** — 쓰임이 없어 수집 자체를 폐지했다(`users.email` 컬럼 삭제, Kakao 동의항목에서도 미요청) |
| 사용자 ID | 수집함 — 카카오 소셜 로그인 식별자, 계정 관리/인증 목적, 필수 |
| 기타(생년월일) | 수집함 — "기타 정보"로 분류, 계정 관리 목적, 필수 |
| 전송 중 암호화 | 예 (HTTPS) |
| 삭제 요청 가능 | 예 (앱 내 회원탈퇴) |

### 앱 활동 (App activity)

| 항목 | 답변 |
|---|---|
| 앱 상호작용 | 수집함 — 퀘스트 완료 이력, 색칠 진행률, 여행 DNA 결과. 앱 기능 제공 목적. 필수(핵심 기능) |
| 전송 중 암호화 | 예 (HTTPS) |
| 삭제 요청 가능 | 예 (앱 내 회원탈퇴) |

## 3. 제3자 공유 요약

| 업체 | 받는 데이터 | 목적 | 분류 |
|---|---|---|---|
| Kakao Corp. | 소셜 로그인 인증 정보 | 로그인 처리 | 서비스 제공자 |
| Google (Gemini API) | 퀘스트 인증 사진(비저장) | AI 사진 판정 | 서비스 제공자 |
| Google Cloud Platform | 전체 서버 데이터 | 인프라·저장소 | 서비스 제공자 |

## 4. 공통 답변

- 모든 데이터는 전송 중 암호화됨 (HTTPS, KAN-64) — **예**
- 사용자가 데이터 삭제를 요청할 수 있음 — **예** (앱 내 회원탈퇴, [withdrawal_pending_screen.dart](../../frontend/lib/features/profile/withdrawal_pending_screen.dart))
- 데이터가 광고 목적으로 쓰이는가 — **아니오** (광고 SDK 없음)
- 독립적 보안 검토를 받았는가 — **아니오** (해당 없으면 체크 안 함)

## 5. 제출 전 마지막 확인

- [ ] 위 표 내용이 실제 Play Console 설문 화면과 1:1로 매핑되는지 확인 (Google이 주기적으로 양식 항목을 바꿈)
- [ ] 개인정보처리방침(`/privacy`) 본문과 이 답변이 서로 모순되지 않는지 재확인
- [ ] 위치정보 "수집 안 함" 신고에 이견이 있으면 [location-law-review.md](../specs/050-quest-verification/location-law-review.md) 재검토
