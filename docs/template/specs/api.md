# API 명세서

## 공통 규약

- **Base URL** : `/api/v1`
- **인증** : 보호 엔드포인트는 `Authorization: Bearer <accessToken>` 헤더 필요
- **응답 Envelope**

```json
{ "code": 200, "message": "SUCCESS", "data": { ... } }
```

- **에러 응답**

```json
{ "code": 404, "message": "NOT_FOUND_ERROR", "data": null }
```

- **인증 여부** : `Y` = 토큰 필요 / `N` = 공개

---

## 엔드포인트 목록

| 기능 | Method | Path | 도메인 | 설명 | 인증 | M |
|------|--------|------|--------|------|------|---|
| AUTH-01/02/04 | POST | `/auth/login/social` | 인증 | 소셜 로그인+가입, 토큰 발급 | N | M1 |
| AUTH-04 | POST | `/auth/refresh` | 인증 | 액세스 토큰 갱신(리프레시) | N | M1 |
| AUTH-03 | POST | `/auth/logout` | 인증 | 로그아웃(토큰 무효화) | Y | M1 |
| USER-01 | GET | `/users/me` | 회원 | 내 정보 조회 | Y | M1 |
| USER-02 | PATCH | `/users/me` | 회원 | 내 정보 수정 | Y | M1 |
| USER-03 | DELETE | `/users/me` | 회원 | 회원 탈퇴(soft delete) | Y | M1 |
| USER-04 | GET | `/users/dna` | 회원 | 내 DNA 결과 | Y | M2 |
| DNA-01 | GET | `/surveys` | DNA | 설문 문항 조회 | Y | M2 |
| DNA-02 | POST | `/surveys/reply` | DNA | 응답 제출 → DNA 산출(재설문 동일) | Y | M2 |
| QST-01 | GET | `/regions` | 퀘스트 | 충북 11개 지역 목록/현황 | Y | M2 |
| QST-02/04 | GET | `/quests` | 퀘스트 | 퀘스트 목록(region, category, sort) | Y | M2 |
| QST-03/05 | GET | `/quests/{id}` | 퀘스트 | 퀘스트 상세(운영정보 포함) | Y | M2 |
| UX-근처 | GET | `/quests/nearby` | 퀘스트 | 근처 퀘스트(lat, lng) | Y | M2 |
| REC-01 | GET | `/quests/recommended` | 추천 | DNA 기반 추천 퀘스트 | Y | M2 |
| REC-02 | GET | `/regions/unvisited` | 추천 | 미방문 지역 추천 | Y | M2 |
| VRF-01 | POST | `/quests/{id}/start` | 인증 | 퀘스트 시작(진행 생성) | Y | M2 |
| VRF-03 | POST | `/uploads/photo` | 공통 | 인증 사진 업로드 | Y | M2 |
| VRF-02/03/04 | POST | `/quests/{id}/verify` | 인증 | GPS+사진 인증 → 완료 처리 | Y | M2 |
| VRF-01 | GET | `/users/me/progress` | 인증 | 내 진행/완료 목록 | Y | M2 |
| MAP-03 | GET | `/users/me/map` | 지도 | 내 지도(지역별 색칠/채도/진행률) | Y | M2 |
| SHR-01/02 | GET | `/users/me/timeline` | 공유 | 여행 타임라인 조회 | Y | M3 |
| SHR-03 | GET | `/users/me/share-card` | 공유 | 공유 카드 데이터(지도+DNA) | Y | M3 |
| EVT-01 | GET | `/festivals` | 이벤트 | 행사/축제 목록(region, date) | Y | M3 |
| EVT-01/02 | GET | `/festivals/nearby` | 이벤트 | 인근/시즌 행사 | Y | M3 |

---

## 상세 명세

### 🔐 인증 (Auth)

---

#### `POST /auth/login/social` — 소셜 로그인 / 회원가입

- **인증** : 불필요
- **설명** : 소셜 OAuth 코드를 받아 로그인 또는 신규 가입 처리 후 토큰을 발급합니다.

---

#### `POST /auth/refresh` — 액세스 토큰 갱신

- **인증** : 불필요
- **설명** : 리프레시 토큰을 사용해 만료된 액세스 토큰을 갱신합니다.

---

#### `POST /auth/logout` — 로그아웃

- **인증** : 필요
- **설명** : 서버에 저장된 리프레시 토큰을 무효화합니다.

---

### 👤 회원 (Users)

---

#### `GET /users/me` — 내 정보 조회

- **인증** : 필요
- **설명** : 현재 로그인한 사용자의 프로필 정보를 반환합니다.

---

#### `PATCH /users/me` — 내 정보 수정

- **인증** : 필요
- **설명** : 닉네임, 프로필 사진 등 사용자 정보를 수정합니다.

---

#### `DELETE /users/me` — 회원 탈퇴

- **인증** : 필요
- **설명** : 회원을 soft delete 처리합니다(`deleted_at` 채움).

---

#### `GET /users/dna` — 내 DNA 결과 조회

- **인증** : 필요
- **설명** : 사용자의 여행 DNA 유형을 반환합니다.

**Response Body**

```json
{
  "success": true,
  "data": {
    "tripDna": "ACTIVITY"
  }
}
```

---

### 🧬 DNA / 설문 (Survey)

---

#### `GET /surveys` — 설문 문항 조회

- **인증** : 필요
- **설명** : 여행 성향 분석을 위한 설문 문항과 선택지 목록을 반환합니다.

**Response Body**

```json
{
  "success": true,
  "data": {
    "questions": [
      {
        "questionId": "a1b2c3d4-0000-0000-0000-000000000001",
        "sortOrder": 1,
        "choices": [
          {
            "choiceId": "c1c1c1c1-0000-0000-0000-000000000001",
            "content": "한적한 자연 속에서 휴식을 즐긴다"
          },
          {
            "choiceId": "c1c1c1c1-0000-0000-0000-000000000002",
            "content": "사람 많은 번화가에서 활기를 느낀다"
          }
        ]
      },
      {
        "questionId": "a1b2c3d4-0000-0000-0000-000000000002",
        "sortOrder": 2,
        "choices": [
          {
            "choiceId": "c2c2c2c2-0000-0000-0000-000000000001",
            "content": "액티비티 위주로 빡빡하게 다닌다"
          },
          {
            "choiceId": "c2c2c2c2-0000-0000-0000-000000000002",
            "content": "느긋하게 카페에서 시간을 보낸다"
          }
        ]
      }
    ]
  }
}
```

---

#### `POST /surveys/reply` — 설문 응답 제출 (DNA 산출)

- **인증** : 필요
- **설명** : 설문 응답을 제출하면 서버에서 DNA 유형을 산출해 반환합니다. 재설문 시에도 동일 엔드포인트를 사용합니다.

**Request Body**

```json
{
  "answers": [
    {
      "questionId": "a1b2c3d4-0000-0000-0000-000000000001",
      "choiceId": "c1c1c1c1-0000-0000-0000-000000000001"
    },
    {
      "questionId": "a1b2c3d4-0000-0000-0000-000000000002",
      "choiceId": "c2c2c2c2-0000-0000-0000-000000000002"
    }
  ]
}
```

**Response Body**

```json
{
  "success": true,
  "data": {
    "tripDna": "ACTIVITY"
  }
}
```

---

### 🗺 퀘스트 (Quest)

---

#### `GET /regions` — 지역 목록 / 현황

- **인증** : 필요
- **설명** : 충북 11개 시·군의 목록과 사용자의 퀘스트 진행 현황을 반환합니다.

---

#### `GET /quests` — 퀘스트 목록

- **인증** : 필요
- **설명** : 퀘스트 목록을 반환합니다. `region`, `category`, `sort` 쿼리 파라미터로 필터링/정렬 가능합니다.

**Query Parameters**

| 파라미터 | 타입 | 필수 | 설명 |
|----------|------|------|------|
| `region` | Long | N | 지역 ID |
| `category` | String | N | `nature` \| `food` \| `history` \| `activity` \| `healing` |
| `sort` | String | N | 정렬 기준 |

---

#### `GET /quests/{id}` — 퀘스트 상세

- **인증** : 필요
- **설명** : 특정 퀘스트의 상세 정보를 반환합니다. 운영정보(시간·휴무)는 관광공사 OpenAPI에서 조회합니다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | Long | 퀘스트 ID |

---

#### `GET /quests/nearby` — 근처 퀘스트

- **인증** : 필요
- **설명** : 현재 위치 기준 반경 내의 퀘스트 목록을 반환합니다.

**Query Parameters**

| 파라미터 | 타입 | 필수 | 설명 |
|----------|------|------|------|
| `lat` | Double | Y | 현재 위도 |
| `lng` | Double | Y | 현재 경도 |

---

### 💡 추천 (Recommend)

---

#### `GET /quests/recommended` — DNA 기반 추천 퀘스트

- **인증** : 필요
- **설명** : 사용자의 여행 DNA 유형에 맞는 퀘스트를 추천합니다.

---

#### `GET /regions/unvisited` — 미방문 지역 추천

- **인증** : 필요
- **설명** : 사용자가 아직 방문하지 않은 지역을 추천합니다.

---

### ✅ 퀘스트 인증 (Verify)

---

#### `POST /quests/{id}/start` — 퀘스트 시작

- **인증** : 필요
- **설명** : 퀘스트 진행 기록을 생성합니다(`status: in_progress`).

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | Long | 퀘스트 ID |

---

#### `POST /uploads/photo` — 인증 사진 업로드

- **인증** : 필요
- **설명** : 인증용 사진을 업로드하고 URL을 반환합니다. `/quests/{id}/verify` 호출 전 먼저 사진 URL을 확보하는 용도입니다.
- **Content-Type** : `multipart/form-data`

---

#### `POST /quests/{id}/verify` — 퀘스트 인증 (GPS + 사진)

- **인증** : 필요
- **설명** : GPS 좌표와 사진 URL을 전달해 퀘스트 완료를 처리합니다. 좌표가 `verify_radius` 이내에 있으면 완료 처리됩니다.

**Path Parameters**

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | Long | 퀘스트 ID |

---

#### `GET /users/me/progress` — 내 진행 / 완료 목록

- **인증** : 필요
- **설명** : 사용자의 퀘스트 진행 중 및 완료 목록을 반환합니다.

---

### 🗺 지도 (Map)

---

#### `GET /users/me/map` — 내 지도

- **인증** : 필요
- **설명** : 지역별 색칠 현황, 채도 단계, 퀘스트 진행률을 반환합니다.

---

### 📤 공유 (Share)

---

#### `GET /users/me/timeline` — 여행 타임라인

- **인증** : 필요
- **설명** : 사용자의 여행 기록(퀘스트 완료, 지역 색칠 등)을 시간순으로 반환합니다.

---

#### `GET /users/me/share-card` — 공유 카드 데이터

- **인증** : 필요
- **설명** : SNS 공유용 카드에 필요한 지도 현황과 DNA 정보를 반환합니다.

---

### 🎪 이벤트 / 행사 (Festival)

---

#### `GET /festivals` — 행사 / 축제 목록

- **인증** : 필요
- **설명** : 지역 또는 날짜로 필터링한 행사·축제 목록을 반환합니다.

**Query Parameters**

| 파라미터 | 타입 | 필수 | 설명 |
|----------|------|------|------|
| `region` | Long | N | 지역 ID |
| `date` | String | N | 조회 기준 날짜 (`YYYY-MM-DD`) |

---

#### `GET /festivals/nearby` — 인근 / 시즌 행사

- **인증** : 필요
- **설명** : 현재 위치 기준 인근에서 열리는 행사 또는 현재 시즌 행사를 반환합니다.

---

## 결정 메모

1. **사진 업로드 방식** — 별도 `/uploads/photo`로 URL 먼저 받기 vs `/verify`에서 multipart 한 번에
2. **추천 분리** — `/quests/recommended`에 `?type=unvisited`로 합치기 vs `/regions/unvisited` 분리
3. **근처/공유/찜** — 어디까지 MVP에 포함할지
4. **페이지네이션** — 목록 API 커서 vs offset (`?page`, `?size`)

---

## P2 (선택 기능)

찜 기능 도입 시 별도 `bookmarks` 테이블 필요

| Method | Path | 설명 |
|--------|------|------|
| POST | `/quests/{id}/bookmark` | 퀘스트 찜 추가 |
| DELETE | `/quests/{id}/bookmark` | 퀘스트 찜 취소 |
| GET | `/users/me/bookmarks` | 내 찜 목록 조회 |