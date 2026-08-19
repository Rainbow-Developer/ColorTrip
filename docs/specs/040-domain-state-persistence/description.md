# [설명] 여행·퀘스트·타임라인 서버 영속화

## 개요

이 기능은 Flutter 메모리에만 있던 여행 선택과 퀘스트 완료 기록을 기존 ColorTrip
백엔드에 연결한다. 사용자가 여행을 만들거나 퀘스트를 인증하면 PostgreSQL에 저장되고,
앱을 종료하거나 다시 로그인한 뒤에도 여행 탭, 지도, 퀘스트 상세, 타임라인이 같은
서버 상태를 표시한다.

화면에 표시하는 220개 퀘스트 콘텐츠는 Flutter 정적 카탈로그를 유지한다. Flutter의
`client_key`와 서버 UUID를 매핑해 API 요청에는 UUID를 사용하고, 서버 응답은 다시
정적 항목에 연결한다.

## 동작 방식

### 여행 생성과 복원

1. Flutter가 `/regions`, `/quests`에서 `slug/client_key ↔ UUID` 매핑을 만든다.
2. 사용자가 정적 카탈로그에서 고른 key를 UUID로 변환한다.
3. 새 여행은 `client_request_id`와 함께 생성하고, 기존 여행의 선택 변경은 원자적
   `PUT /journeys/{id}/quests`로 저장한다.
4. 앱은 `GET /journeys` 스냅샷으로 지역별 진행중 여행과 `/journey/:journeyId` 상세를 복원하고, 서버의 단건 상세 계약은 `GET /journeys/{id}`로 유지한다.
5. 응답 유실 후 같은 `client_request_id`를 재전송해도 여정은 한 건만 존재한다.

### 퀘스트 인증과 파생 상태

1. 사진은 `/uploads/photo` 업로드 결과, GPS는 실제 현재 위치, 퀴즈는 선택 답안을
   `/quests/{id}/verify`에 제출한다.
2. 서버가 미션 타입별 규칙과 여정 소유권을 검증한다.
3. 성공한 한 트랜잭션 안에서 `quest_progress`, 관련 여정 상태, `map_progress`,
   타임라인 이벤트를 갱신한다.
4. Flutter는 성공 후 관련 Provider를 invalidate하고 서버 결과를 다시 읽는다.
5. 앱 재시작 시 화면별 Provider가 같은 API를 조회하므로 메모리 초기화와 무관하게 복원된다.

### 오류와 계정 경계

- timeout·네트워크 오류는 성공으로 간주하지 않고 사용자가 같은 입력으로 재시도한다.
- catalog key 매핑이 없거나 중복이면 잘못된 UUID를 보내지 않고 명시적 데이터 오류를 표시한다.
- 401은 KAN-53 interceptor가 refresh를 한 번 수행하고, 재실패하면 인증 상태를 정리한다.
- 로그아웃·탈퇴·다른 계정 로그인 시 사용자별 서버 Provider를 폐기한다.

## 주요 구성 요소 / 위치

| 구성 요소 | 역할 | 위치 |
|-----------|------|------|
| 지역·퀘스트 stable key | 정적 ID와 서버 UUID 연결 | `backend/app/regions/`, `backend/app/quests/` |
| 여정·인증 서비스 | 멱등 생성, 원자적 선택, 완료 트랜잭션 | `backend/app/journeys/`, `backend/app/quests/` |
| catalog snapshot migration | 11개 지역·220개 퀘스트 서버 준비 | `backend/alembic/versions/` |
| Flutter 도메인 Repository | Envelope·페이지네이션·API 모델 변환 | `frontend/lib/data/repositories/` |
| Flutter 도메인 Provider | 사용자별 여정·진행·지도·타임라인 서버 상태 | `frontend/lib/state/` |
| 관련 화면 | 지역별 여행 탐색, 여행 상세, 저장·인증 UX | `frontend/lib/features/quests/`, `frontend/lib/features/travel/` |

## 설정 / 사용법

새로운 비밀 환경변수는 추가하지 않는다. 기존 `API_BASE_URL`, ColorTrip JWT,
업로드 저장소 설정을 사용한다. Android GPS 인증은 위치 권한과 위치 서비스가 필요하며,
사용자가 거부하면 완료 처리 없이 설정 안내와 재시도를 제공한다.

## 예시

```http
POST /api/v1/journeys
Authorization: Bearer <access-token>
Content-Type: application/json

{
  "client_request_id": "019c0000-0000-7000-8000-000000000001",
  "region_id": "019c0000-0000-7000-8000-000000000002",
  "quest_ids": ["019c0000-0000-7000-8000-000000000003"],
  "title": "단양 여행",
  "start_date": "2026-07-28",
  "end_date": "2026-07-29"
}
```

```http
PUT /api/v1/journeys/019c0000-0000-7000-8000-000000000010/quests
Authorization: Bearer <access-token>
Content-Type: application/json

{
  "quest_ids": [
    "019c0000-0000-7000-8000-000000000003",
    "019c0000-0000-7000-8000-000000000004"
  ]
}
```

## 관련 문서

- [plan.md](plan.md) · [implementation.md](implementation.md)
- [000 Flutter 앱](../000-frontend-app/)
- [000 퀘스트](../000-quest/)
- [010 여정·퀘스트 인증](../010-journey/)
- [025 여행 타임라인](../025-travel-timeline/)
- [035 Kakao 통합 인증](../035-kakao-auth-integration/)
- [API 설계](../../conventions/api-design.md) · [DB](../../conventions/database.md) ·
  [인증·보안](../../conventions/auth-security.md)
