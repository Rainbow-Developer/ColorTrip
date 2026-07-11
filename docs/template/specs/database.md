# PostgreSQL DDL

## ENUM TYPE

```sql
CREATE TYPE dna_type AS ENUM (
    'NATURE',
    'FOOD',
    'HISTORY',
    'ACTIVITY',
    'HEALING'
);
```

---

## 1. users — 사용자
- 소셜 로그인 기반 사용자 정보를 저장하는 테이블
- DNA 컬럼은 여행 성향 설문 완료 후 채워짐
- UNIQUE (social_provider, social_id)는 같은 소셜 계정 중복 가입 방지

```sql
CREATE TABLE users (
    id               UUID GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    social_provider  VARCHAR(20)  NOT NULL,
    social_id        VARCHAR(100) NOT NULL,
    email            VARCHAR(255),
    nickname         VARCHAR(30),
    birth_date       DATE,
    dna              dna_type,
    profile_image    VARCHAR(500),
    created_at       TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMP    NOT NULL DEFAULT NOW(),
    deleted_at       TIMESTAMP,

    CONSTRAINT uq_users_social UNIQUE (social_provider, social_id)
);
```

---

## 2. refresh_tokens — 리프레시 토큰
- JWT 리프레시 토큰을 해시값으로 저장하는 테이블
- 원본 토큰 대신 hash를 저장해 DB 유출 시 토큰 재사용 불가
- user_id 인덱스로 로그인한 사용자의 토큰 목록 조회·무효화에 활용

```sql
CREATE TABLE refresh_tokens (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     BIGINT       NOT NULL REFERENCES users (id),
    token_hash  VARCHAR(255) NOT NULL,
    expires_at  TIMESTAMP    NOT NULL,
    created_at  TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP    NOT NULL DEFAULT NOW(),
    deleted_at  TIMESTAMP
);

CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens (user_id);
```

---

## 3. regions — 충북 시·군 마스터
- 충청북도 시·군 단위 마스터 데이터 테이블
- area_code는 한국관광공사 API의 지역 코드로, 축제·관광지 API 연동에 사용

```sql
CREATE TABLE regions (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(30)   NOT NULL,
    area_code   VARCHAR(20)   UNIQUE,
    created_at  TIMESTAMP     NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP     NOT NULL DEFAULT NOW(),
    deleted_at  TIMESTAMP
);
```

---

## 4. quests — 퀘스트
- 지역별 퀘스트(미션) 정보를 저장하는 테이블
- mission_type은 인증 방식(기본값 `gps_photo`: 위치 확인 + 사진 업로드), mission_meta는 미션별 추가 조건을 JSONB로 유연하게 저장
- content_id / content_type_id는 한국관광공사 TourAPI 관광지 식별자로, 퀘스트와 관광 콘텐츠를 연계
- lat/lng는 퀘스트 인증 기준 좌표, verify_radius(m)는 인증 가능 반경

```sql
CREATE TABLE quests (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    region_id        BIGINT       NOT NULL REFERENCES regions (id),
    title            VARCHAR(100) NOT NULL,
    description      TEXT,
    category         VARCHAR(20)  NOT NULL
                         CHECK (category IN ('nature', 'food', 'history', 'activity', 'healing')),
    mission_type     VARCHAR(30)  NOT NULL DEFAULT 'gps_photo',
    mission_meta     JSONB,
    content_id       VARCHAR(50),
    content_type_id  VARCHAR(20),
    lat              DECIMAL(10,7),
    lng              DECIMAL(10,7),
    verify_radius    INT          NOT NULL DEFAULT 200,
    thumbnail_url    VARCHAR(500),
    created_at       TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMP    NOT NULL DEFAULT NOW(),
    deleted_at       TIMESTAMP
);

CREATE INDEX idx_quests_region_category ON quests (region_id, category);
```

---

## 5. quest_progress — 퀘스트 진행/인증
- 사용자별 퀘스트 인증 기록을 저장하는 테이블
- UNIQUE (user_id, quest_id)로 동일 퀘스트 중복 완료 방지
- 완료(completed) 시 인증 좌표(verified_lat/lng), 사진(photo_url), 완료 시각(completed_at) 기록
- map_progress.completed_count 집계와 timeline_events 생성의 트리거가 되는 핵심 테이블

```sql
CREATE TABLE quest_progress (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id       BIGINT        NOT NULL REFERENCES users (id),
    quest_id      BIGINT        NOT NULL REFERENCES quests (id),
    status        VARCHAR(20)   NOT NULL DEFAULT 'in_progress'
                      CHECK (status IN ('in_progress', 'completed')),
    verified_lat  DECIMAL(10,7),
    verified_lng  DECIMAL(10,7),
    photo_url     VARCHAR(500),
    completed_at  TIMESTAMP,
    created_at    TIMESTAMP     NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMP     NOT NULL DEFAULT NOW(),
    deleted_at    TIMESTAMP,

    CONSTRAINT uq_quest_progress_user_quest UNIQUE (user_id, quest_id)
);

CREATE INDEX idx_quest_progress_user_status ON quest_progress (user_id, status);
```

---

## 6. map_colors — 지역 색칠
- 사용자가 특정 지역에서 완료한 퀘스트 수를 집계하는 테이블
- completed_count가 증가할수록 지도상 해당 지역이 더 진하게 색칠되는 시각적 진행도를 표현
- first_colored_at은 해당 지역에서 첫 퀘스트를 완료한 시각 (지도 색칠 최초 시점)
- UNIQUE (user_id, region_id)로 사용자별 지역 집계가 단건으로 유지됨

```sql
CREATE TABLE map_progress (
    id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id           BIGINT    NOT NULL REFERENCES users (id),
    region_id         BIGINT    NOT NULL REFERENCES regions (id),
    completed_count   INT       NOT NULL DEFAULT 0,
    first_colored_at  TIMESTAMP,
    created_at        TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at        TIMESTAMP,

    CONSTRAINT uq_map_progress_user_region UNIQUE (user_id, region_id)
);
```

---

## 7. timeline_events — 여행 타임라인
- 사용자의 여행 활동 이력을 시계열로 기록하는 테이블
- quest_progress_id는 퀘스트 완료 이벤트일 때 해당 인증 레코드와 연결 (선택적)
- event_type으로 퀘스트 완료·지역 첫 방문·DNA 업데이트 등 이벤트 종류를 구분
- occurred_at DESC 인덱스로 타임라인 피드(최신순) 조회 최적화

```sql
CREATE TABLE timeline_events (
    id                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id            BIGINT      NOT NULL REFERENCES users (id),
    quest_progress_id  BIGINT,
    event_type         VARCHAR(30) NOT NULL,
    title              VARCHAR(100),
    occurred_at        TIMESTAMP   NOT NULL,
    created_at         TIMESTAMP   NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMP   NOT NULL DEFAULT NOW(),
    deleted_at         TIMESTAMP
);

CREATE INDEX idx_timeline_events_user_occurred ON timeline_events (user_id, occurred_at DESC);
```

---

## 9. trip_questions — 여행 성향 질문지
- 여행 DNA 설문의 질문 목록을 저장하는 테이블
- sort_order로 앱에 출제되는 질문 순서를 제어

```sql
CREATE TABLE trip_questions (
    id          UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
    question    TEXT      NOT NULL,
    sort_order  INTEGER,
    is_deleted  BOOLEAN   NOT NULL DEFAULT FALSE,
    deleted_at  TIMESTAMP,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP NOT NULL DEFAULT NOW()
);
```

---

## 10. trip_question_options — 선택지
- 각 질문의 선택지를 저장하는 테이블
- score_value JSONB에 DNA 유형별 점수 기여값이 담겨 있어 설문 완료 후 DNA 산출에 사용 (예: `{"nature":3,"food":1,...}`)
- category는 이 선택지가 주로 대응하는 DNA 유형으로, 결과 해석 참고용
- question_id 인덱스로 질문별 선택지 목록 조회 최적화

```sql
CREATE TABLE trip_question_options (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id  UUID        NOT NULL REFERENCES trip_questions (id),
    score_value  JSONB       NOT NULL,  -- {"nature":3,"food":1,"history":2,"activity":3,"healing":0}
    content      TEXT        NOT NULL,
    category     VARCHAR(20) NOT NULL
                     CHECK (category IN ('NATURE', 'FOOD', 'HISTORY', 'ACTIVITY', 'HEALING')),
    sort_order   INTEGER,
    is_deleted   BOOLEAN     NOT NULL DEFAULT FALSE,
    deleted_at   TIMESTAMP,
    created_at   TIMESTAMP   NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMP   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_trip_question_options_question_id ON trip_question_options (question_id);
```

---

## 11. trip_replies — 여행 성향 사용자 답변
- 여행 DNA 설문에 대한 사용자의 문항별 응답을 저장하는 테이블
- question_id, question_option_id는 각각 trip_questions, trip_question_options 테이블의 id값
```sql
CREATE TABLE trip_replies (
    id                  UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID      NOT NULL,
    question_id         UUID      NOT NULL,
    question_option_id  UUID      NOT NULL,
    is_deleted          BOOLEAN   NOT NULL DEFAULT FALSE,
    deleted_at          TIMESTAMP,
    created_at          TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_trip_replies_user_id ON trip_replies (user_id);
CREATE INDEX idx_trip_replies_user_created ON trip_replies (user_id, created_at DESC);
```

---

## 12. user_dna_history — 여행 성향 결과 이력
- 여행 DNA 설문에 대한 결과를 저장하는 히스토리성 테이블
```sql
CREATE TABLE user_dna_history (
    id          UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID      NOT NULL,
    dna         dna_type  NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_user_dna_history_user_created ON user_dna_history (user_id, created_at DESC);
```