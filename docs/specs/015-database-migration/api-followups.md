# API 후속 작업 기록

이 문서는 PR #15 `database.md`를 Alembic migration으로 반영한 뒤 API 쪽에서 확인해야 할 지점을 추적한다.

## GitHub Issue 생성 기준

이번 migration에서 GitHub Issue로 생성/유지하는 대상은 **테이블 구성이 변경되어 기존 구현된 API에 수정이 필요할 수 있는 지점**으로 한정한다. 아직 구현되지 않은 신규 API는 후보로만 기록하고, 이번 migration 후속 이슈로는 생성하지 않는다.

## 이슈화 대상: 기존 구현 영향

| 구분 | 기존 구현 API | 관련 DB/컬럼 | 검토/수정 필요 지점 | 상태 | GitHub Issue |
|------|---------------|--------------|---------------------|------|--------------|
| 사용자 프로필 응답 | `POST /auth/login/social`, `GET /users/me` | `users.dna`, `users.profile_image` | 기존 `UserProfile` 응답에 DNA/프로필 이미지 nullable 필드를 포함할지, Kakao profile image를 로그인에서 수집할지 검토 | 이슈 유지 | [#18](https://github.com/Rainbow-Developer/ColorTrip/issues/18) |
| 퀘스트 조회 응답 | `GET /quests`, `GET /quests/{id}` | `quest_progress` | 기존 퀘스트 목록/상세 응답에 사용자별 진행 상태를 포함할지, 인증 필수/선택 인증 정책을 어떻게 둘지 검토 | 이슈 유지 | [#20](https://github.com/Rainbow-Developer/ColorTrip/issues/20) |
| 지역 목록 응답 | `GET /regions` | `map_progress`, `regions` | 기존 지역 목록 응답에 사용자별 완료 수/최초 색칠 시각을 포함할지, 공개 API 호환성을 어떻게 유지할지 검토 | 이슈 유지 | [#21](https://github.com/Rainbow-Developer/ColorTrip/issues/21) |

## 기록만 남기는 신규 API 후보

아래 항목은 PR #15 API 문서상 필요할 수 있지만, 현재 `dev`에 구현된 API를 수정하는 성격이 아니므로 이번 migration 후속 GitHub Issue로 유지하지 않는다. 추후 해당 기능을 실제 구현할 때 별도 기능 이슈로 생성한다.

| 후보 API | 관련 DB/컬럼 | 비고 |
|----------|--------------|------|
| `GET /users/dna`, `GET /surveys`, `POST /surveys/reply` | `users.dna`, `trip_questions`, `trip_question_options`, `trip_replies`, `user_dna_history` | 신규 DNA/설문 API |
| `POST /quests/{id}/start`, `POST /quests/{id}/verify`, `GET /users/me/progress` | `quest_progress` | 신규 퀘스트 진행/인증 API |
| `GET /quests/nearby`, `GET /quests/recommended` | `quest_progress`, `users.dna`, `quests` | 신규 퀘스트 탐색/추천 API |
| `GET /users/me/map`, `GET /regions/unvisited` | `map_progress`, `regions` | 신규 지도/지역 진행 API |
| `GET /users/me/timeline`, `GET /users/me/share-card` | `timeline_events`, `map_progress`, `users.dna` | 신규 타임라인/공유 API |
| `POST /uploads/photo` | `quest_progress.photo_url` | 신규 업로드 API |

## 참고 기준

- PR #15 `docs/template/specs/database.md`, `docs/template/specs/api.md`를 우선 기준으로 삼는다.
- PR #17은 인증/진행 구현 참고 자료로만 사용하고 이번 migration의 기준으로 삼지 않는다.
- API 응답 형식은 `docs/conventions/api-design.md`의 `code/status/message/data` Envelope를 따른다.
