# PostgreSQL DDL

> **작성 기준**
> - 초안 테이블 PK: `BIGINT GENERATED ALWAYS AS IDENTITY`
> - 여행 성향 테이블 PK: `UUID` (`gen_random_uuid()`)
> - `DATETIME` → PostgreSQL `TIMESTAMP`
> - `dna` ENUM: `CREATE TYPE dna_type` 으로 분리
> - `score_value`: `JSONB` (`{"nature":3, "food":1, ...}`)
> - `category`: `VARCHAR(20)` + `CHECK` 제약

---

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

```sql
CREATE TABLE users (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
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

## 3. survey_answers — 초기 설문 응답

```sql
CREATE TABLE survey_answers (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id        BIGINT       NOT NULL REFERENCES users (id),
    question_code  VARCHAR(50)  NOT NULL,
    answer_value   VARCHAR(100) NOT NULL,
    created_at     TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMP    NOT NULL DEFAULT NOW(),
    deleted_at     TIMESTAMP
);

CREATE INDEX idx_survey_answers_user_id ON survey_answers (user_id);
```

---

## 4. travel_dna — 여행 DNA (users 1:1)

```sql
CREATE TABLE travel_dna (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id       BIGINT      NOT NULL REFERENCES users (id),
    primary_type  VARCHAR(20) NOT NULL,
    scores        JSONB,
    created_at    TIMESTAMP   NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMP   NOT NULL DEFAULT NOW(),
    deleted_at    TIMESTAMP,

    CONSTRAINT uq_travel_dna_user_id UNIQUE (user_id)
);
```

---

## 5. regions — 충북 시·군 마스터

```sql
CREATE TABLE regions (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(30)   NOT NULL,
    area_code   VARCHAR(20)   UNIQUE,
    center_lat  DECIMAL(10,7),
    center_lng  DECIMAL(10,7),
    created_at  TIMESTAMP     NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP     NOT NULL DEFAULT NOW(),
    deleted_at  TIMESTAMP
);
```

---

## 6. quests — 퀘스트

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

## 7. quest_progress — 퀘스트 진행/인증

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

## 8. map_progress — 지역 색칠 (user × region)

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

## 9. timeline_events — 여행 타임라인

```sql
CREATE TABLE timeline_events (
    id                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id            BIGINT      NOT NULL REFERENCES users (id),
    quest_progress_id  BIGINT      REFERENCES quest_progress (id),
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

## 10. festivals — 행사/축제

```sql
CREATE TABLE festivals (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    region_id      BIGINT       REFERENCES regions (id),
    title          VARCHAR(150) NOT NULL,
    content_id     VARCHAR(50),
    start_date     DATE,
    end_date       DATE,
    location       VARCHAR(200),
    thumbnail_url  VARCHAR(500),
    created_at     TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMP    NOT NULL DEFAULT NOW(),
    deleted_at     TIMESTAMP
);

CREATE INDEX idx_festivals_region_start ON festivals (region_id, start_date);
```

---

## 11. trip_questions — 여행 성향 질문지

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

## 12. trip_question_options — 선택지

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

## 13. trip_replies — 여행 성향 사용자 답변

```sql
CREATE TABLE trip_replies (
    id                  UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID      NOT NULL,
    question_id         UUID      NOT NULL REFERENCES trip_questions (id),
    question_option_id  UUID      NOT NULL REFERENCES trip_question_options (id),
    is_deleted          BOOLEAN   NOT NULL DEFAULT FALSE,
    deleted_at          TIMESTAMP,
    created_at          TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_trip_replies_user_id ON trip_replies (user_id);
CREATE INDEX idx_trip_replies_user_created ON trip_replies (user_id, created_at DESC);
```

---

## 14. user_dna_history — 여행 성향 결과 이력

```sql
CREATE TABLE user_dna_history (
    id          UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID      NOT NULL,
    dna         dna_type  NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_user_dna_history_user_created ON user_dna_history (user_id, created_at DESC);
```