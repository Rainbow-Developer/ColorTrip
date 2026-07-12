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

---

## 상세 명세

### 🔐 인증 (Auth)

---

#### `POST /auth/login/social` — 소셜 로그인 / 회원가입

- **인증** : 불필요
- **설명** : 소셜 OAuth 코드를 받아 로그인 또는 신규 가입 처리 후 토큰을 발급합니다.
- 소셜 provider에서 발급한 OAuth 코드를 서버에서 검증해 사용자 정보를 확인
- `users` 테이블에 `(social_provider, social_id)` 조합이 없으면 신규 레코드 생성, 있으면 로그인 처리 (단일 엔드포인트에서 가입+로그인 통합)
- 응답으로 단기 액세스 토큰과 장기 리프레시 토큰을 함께 발급하며, 리프레시 토큰은 `refresh_tokens` 테이블에 해시로 저장

---

#### `POST /auth/refresh` — 액세스 토큰 갱신

- **인증** : 불필요
- **설명** : 리프레시 토큰을 사용해 만료된 액세스 토큰을 갱신합니다.
- 전달된 리프레시 토큰을 해시화해 `refresh_tokens.token_hash`와 비교, 유효하지 않거나 만료된 경우 401 반환
- 토큰 로테이션 적용: 기존 리프레시 토큰을 무효화(`deleted_at` 채움)하고 새 리프레시 토큰도 함께 발급

---

#### `POST /auth/logout` — 로그아웃

- **인증** : 필요
- **설명** : 서버에 저장된 리프레시 토큰을 무효화합니다.
- `refresh_tokens` 테이블의 해당 토큰 레코드에 `deleted_at`을 채워 소프트 삭제 처리
- 클라이언트는 로컬에 저장된 토큰을 별도로 삭제 필요 (서버는 리프레시 토큰만 관리)

---

### 👤 회원 (Users)

---

#### `GET /users/me` — 내 정보 조회

- **인증** : 필요
- **설명** : 현재 로그인한 사용자의 프로필 정보를 반환합니다.
- 액세스 토큰에서 추출한 `user_id`로 `users` 테이블을 조회
- `dna`가 null이면 클라이언트에서 설문 화면으로 유도하는 분기에 활용 가능

---

#### `PATCH /users/me` — 내 정보 수정

- **인증** : 필요
- **설명** : 닉네임, 프로필 사진 등 사용자 정보를 수정합니다.
- 요청에 포함된 필드만 업데이트하고 나머지는 기존 값 유지
- 수정 가능 필드: `nickname`, `profile_image`

---

#### `DELETE /users/me` — 회원 탈퇴

- **인증** : 필요
- **설명** : 회원을 soft delete 처리합니다(`deleted_at` 채움).
- `users.deleted_at`에 현재 시각을 기록하며, 물리 삭제는 하지 않음 (이력 보존 및 2년 후 물리삭제)


---

#### `GET /users/dna` — 내 DNA 결과 조회

- **인증** : 필요
- **설명** : 사용자의 여행 DNA 유형을 반환합니다.
- `users.dna` 컬럼 값(`NATURE` / `FOOD` / `HISTORY` / `ACTIVITY` / `HEALING`)을 반환
- 설문을 완료하지 않은 경우 `tripDna: null` 반환

---

### 🧬 DNA / 설문 (Survey)

---

#### `GET /surveys` — 설문 문항 조회

- **인증** : 필요
- **설명** : 여행 성향 분석을 위한 설문 문항과 선택지 목록을 반환합니다.
- `trip_questions` + `trip_question_options` 테이블에서 `is_deleted = false`인 항목을 `sort_order` 오름차순으로 반환


---

#### `POST /surveys/reply` — 설문 응답 제출 (DNA 산출)

- **인증** : 필요
- **설명** : 설문 응답을 제출하면 서버에서 DNA 유형을 산출해 반환합니다. 재설문 시에도 동일 엔드포인트를 사용합니다.
- 문항별 선택지의 `score_value`(JSONB)를 합산해 가장 높은 점수의 DNA 유형 결정
- `trip_replies`에 응답 저장 후 `users.dna` 갱신 및 `user_dna_history`에 이력 추가
- 재설문 시에도 동일 엔드포인트: 기존 응답을 덮어쓰고 새 DNA로 갱신

---

### 🗺 퀘스트 (Quest)

---

#### `GET /regions` — 지역 목록 / 현황

- **인증** : 필요
- **설명** : 충북 11개 시·군의 목록과 사용자의 퀘스트 진행 현황을 반환합니다.
- `regions` 테이블 전체 목록에 `map_progress`를 조인해 각 지역의 `completed_count`와 첫 방문 시각(`first_colored_at`)을 포함
- 지도 화면 진입 시 초기 데이터 로드에 사용

---

#### `GET /quests` — 퀘스트 목록

- **인증** : 필요
- **설명** : 퀘스트 목록을 반환합니다. `region`, `category`, `sort` 쿼리 파라미터로 필터링/정렬 가능합니다.
- `quest_progress`를 LEFT JOIN해 사용자의 퀘스트 완료 여부(`status`)도 함께 응답
- `region` 미지정 시 전체 지역, `category` 미지정 시 전체 카테고리 반환

---

#### `GET /quests/{id}` — 퀘스트 상세

- **인증** : 필요
- **설명** : 특정 퀘스트의 상세 정보를 반환합니다. 운영정보(시간·휴무)는 관광공사 OpenAPI에서 조회합니다.
- `quests` 테이블 기본 정보 + `content_id`로 한국관광공사 TourAPI를 호출해 운영시간·휴무일 병합
- 외부 API 장애 시 기본 정보만 반환하고 운영정보는 `null` 처리 (장애가 전체 응답을 막지 않음)
- 사용자의 해당 퀘스트 `quest_progress` 상태도 포함

---

#### `GET /quests/nearby` — 근처 퀘스트

- **인증** : 필요
- **설명** : 현재 위치 기준 반경 내의 퀘스트 목록을 반환합니다.
- 전달한 `lat`/`lng`와 `quests.lat`/`lng`를 Haversine 공식으로 거리 계산, 가까운 순으로 정렬
- 사용자 `quest_progress` 조인으로 완료 여부 포함

---

### 💡 추천 (Recommend)

---

#### `GET /quests/recommended` — DNA 기반 추천 퀘스트

- **인증** : 필요
- **설명** : 사용자의 여행 DNA 유형에 맞는 퀘스트를 추천합니다.
- `users.dna` 유형과 일치하는 `category`의 퀘스트를 우선 추천
- 이미 완료(`status = completed`)한 퀘스트는 제외하고 미완료 퀘스트만 반환

---

#### `GET /regions/unvisited` — 미방문 지역 추천

- **인증** : 필요
- **설명** : 사용자가 아직 방문하지 않은 지역을 추천합니다.
- `map_progress`에 레코드가 없거나 `completed_count = 0`인 `regions`를 반환
- 방문 이력 없는 지역 탐색 동기를 부여하는 데 사용

---

### ✅ 퀘스트 인증 (Verify)

---

#### `POST /quests/{id}/start` — 퀘스트 시작

- **인증** : 필요
- **설명** : 퀘스트 진행 기록을 생성합니다(`status: in_progress`).
- `quest_progress`에 `status = 'in_progress'`로 레코드 생성
- 동일 `(user_id, quest_id)` 조합의 레코드가 이미 존재하면 에러 반환 (중복 시작 방지)

---

#### `POST /uploads/photo` — 인증 사진 업로드

- **인증** : 필요
- **설명** : 인증용 사진을 업로드하고 URL을 반환합니다. `/quests/{id}/verify` 호출 전 먼저 사진 URL을 확보하는 용도입니다.
- 이미지를 스토리지(GCS/S3)에 업로드 후 퍼블릭 URL 반환
- 반환된 URL을 `POST /quests/{id}/verify`의 `photo_url` 필드에 전달하는 2-step 흐름
- **Content-Type** : `multipart/form-data`

---

#### `POST /quests/{id}/verify` — 퀘스트 인증 (GPS + 사진)

- **인증** : 필요
- **설명** : GPS 좌표와 사진 URL을 전달해 퀘스트 완료를 처리합니다. 좌표가 `verify_radius` 이내에 있으면 완료 처리됩니다.
- 전달된 좌표(`lat`, `lng`)가 `quests.verify_radius`(m) 이내인지 Haversine으로 검증, 범위 밖이면 400 반환
- 검증 통과 시 `quest_progress.status = 'completed'` 갱신 및 `verified_lat`, `verified_lng`, `photo_url`, `completed_at` 기록
- 완료 처리 후 `map_progress.completed_count` 증가 및 `timeline_events` 레코드 추가

---

#### `GET /users/me/progress` — 내 진행 / 완료 목록

- **인증** : 필요
- **설명** : 사용자의 퀘스트 진행 중 및 완료 목록을 반환합니다.
- `quest_progress` 테이블에서 `user_id` 기준으로 조회
- `status` 쿼리 파라미터로 `in_progress` / `completed` 구분 조회 지원

---

### 🗺 지도 (Map)

---

#### `GET /users/me/map` — 내 지도

- **인증** : 필요
- **설명** : 지역별 색칠 현황, 채도 단계, 퀘스트 진행률을 반환합니다.
- `map_progress` 테이블에서 사용자별 지역 색칠 현황(`completed_count`, `first_colored_at`) 조회
- `completed_count` 기준으로 채도 단계를 계산해 응답 (클라이언트는 단계값으로 색칠 강도 표현)

---

### 📤 공유 (Share)

---

#### `GET /users/me/timeline` — 여행 타임라인

- **인증** : 필요
- **설명** : 사용자의 여행 기록(퀘스트 완료, 지역 색칠 등)을 시간순으로 반환합니다.
- `timeline_events` 테이블에서 `user_id` 기준으로 `occurred_at DESC` 정렬 + 페이지네이션 조회
- `event_type`별로 클라이언트 UI 표현이 다름 (퀘스트 완료·지역 첫 방문·DNA 업데이트 등)

---

#### `GET /users/me/share-card` — 공유 카드 데이터

- **인증** : 필요
- **설명** : SNS 공유용 카드에 필요한 지도 현황과 DNA 정보를 반환합니다.
- `map_progress` 집계(지역별 색칠 현황) + `users.dna` 를 조합해 카드 구성 데이터 반환
- 클라이언트에서 이 데이터를 렌더링해 SNS 공유 이미지를 생성하는 흐름

---
