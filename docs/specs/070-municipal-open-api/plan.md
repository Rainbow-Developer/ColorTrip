# [계획] 지자체 제공 오픈 API (지역 관광 통계)

| 항목 | 내용 |
|------|------|
| 기능명 | 지자체 오픈 API |
| Spec 폴더 | `docs/specs/070-municipal-open-api/` |
| 영역 | backend |
| 작성자 | Claude (AI) |
| 작성일 | 2026-08-03 |
| 상태 | 계획 |

## 배경 / 목적
* 지자체(시·군청 등)에 다채로울지도의 관광 활동 데이터를 통계 형태로 제공한다.
* 이 앱이 지금 한국관광공사 TourAPI를 **소비**하는 입장(`backend/app/integrations/tour_api/`)인 것처럼, 이번엔 반대로 우리가 **제공자**가 되어 같은 스타일(서비스키 기반 오픈 API, 지역 선택 조회)로 데이터를 내준다.
* 개인 식별 정보는 노출하지 않는다 — 이 앱은 회원 탈퇴 시 즉시 익명화하는 정책([auth-security.md](../../conventions/auth-security.md))을 쓸 만큼 개인정보에 민감하므로, 지자체 API는 처음부터 **집계·통계** 형태로만 설계한다.

## 목표 (Goals)
* 지역(시·군)을 선택해 조회하는 오픈 API 1세트를 만든다. 서비스키 하나로 **모든 지역**을 조회할 수 있다(지자체별 접근 지역 제한 없음 — 공공데이터포털 오픈 API와 같은 성격).
* 첫 버전에서 아래 7개 통계를 한 응답에 담는다(전부 한 번에 구현):
  1. **방문 인증 통계** — 기간별(월별) 완료 퀘스트 수 추이
  2. **인기 관광지 랭킹** — 완료 수 기준 상위 퀘스트(장소)
  3. **여행자 성향(DNA) 분포** — 그 지역을 방문한 사용자의 DNA 유형 비율
  4. **여정 완주 통계** — 시작 대비 완료율, 평균 완주 소요일수
  5. **인증 방식별 참여율** — GPS/사진/QR/퀴즈 비율
  6. **월별 방문 추이** — 최근 N개월 시계열
  7. **공유(바이럴) 통계** — 공유 생성 수, 스타일별 비율
* 서비스키 검증 실패 시 명확한 에러(401)를 반환한다.

## 비목표 (Non-Goals)
* 지자체 → 앱 방향의 역방향 API(축제/이벤트 등록 등) — 이번 스펙에서 제외, 필요해지면 별도 스펙.
* 지자체별로 자기 지역만 보게 하는 접근 제한 — 서비스키는 전 지역 조회 권한을 준다(오픈API 성격).
* 실사용 수준의 요청량 제한(rate limiting) 인프라 — 키 발급/검증만 다루고, 트래픽 제어는 후속 과제로 남긴다.
* k-익명성(표본이 너무 작을 때 개인이 특정될 위험) 같은 고급 비식별 처리 — 알려진 한계로 기록만 하고 이번 범위에서 막지 않는다(지역 단위 집계라 위험이 낮다고 판단).

## 요구사항
* `serviceKey` 쿼리 파라미터로 인증한다(TourAPI 소비 경험과 동일한 관례 — 지자체 담당자에게 익숙한 방식).
* 키는 서버에서 발급·해시 저장하고, 비활성화(회수)할 수 있어야 한다.
* 응답은 기존 Envelope(`code/status/message/data`) 규격을 따른다([api-design.md](../../conventions/api-design.md)).
* 존재하지 않는 지역 slug 조회 시 404, 유효하지 않은/누락된 서비스키는 401을 반환한다.

## 설계 개요 / 접근 방식

**신규 모듈**: `backend/app/open_api/`(models·schemas·repository·service·router)

**API 키 저장**: `open_api_keys` 테이블(UUID PK, `name`(발급 대상 이름, 예: "단양군청"), `key_hash`, `is_active`, 타임스탬프 믹스인). 원문 키는 발급 시 1회만 노출하고 DB에는 해시만 저장한다(`JWT_SECRET_KEY` 같은 패턴과 다르게, 이건 비밀번호형 키라 해시 비교가 적절 — bcrypt 등 기존 프로젝트에 이미 있는 해시 유틸 재사용).

**인증 방식**: FastAPI dependency(`ActiveOpenApiKey` 같은 이름)가 `serviceKey` 쿼리 파라미터를 읽어 해시 비교 후 유효하지 않으면 401. 기존 `ActiveUser`/`CurrentUser`(JWT 기반)와는 별개 인증 축이다 — 사용자 로그인이 아니라 기관 대 기관 접근이므로 혼용하지 않는다.

**엔드포인트**: `GET /api/v1/open/regions/{region_slug}/stats?serviceKey=...&months=6`
* `region_slug`는 기존 `regions.slug`(예: `danyang`)를 그대로 쓴다 — 지역 목록은 이미 공개인 `GET /api/v1/regions`를 그대로 안내하면 되므로 별도 엔드포인트를 만들지 않는다.
* `months`(선택, 기본 6): 월별 추이·방문 통계 집계 기간.

**응답 스키마 초안**:
```json
{
  "region": { "id": "...", "name": "단양군", "slug": "danyang" },
  "visit_stats": { "total_completed_quests": 1234, "monthly": [{"month": "2026-07", "count": 210}] },
  "popular_spots": [{"quest_id": "...", "title": "온달산성 전설 OX 퀴즈", "completed_count": 88}],
  "dna_distribution": {"nature": 0.32, "food": 0.18, "history": 0.21, "activity": 0.15, "healing": 0.14},
  "journey_completion": {"started": 340, "completed": 210, "completion_rate": 0.62, "avg_days_to_complete": 3.4},
  "verification_method_breakdown": {"photo": 0.7, "gps": 0.15, "quiz": 0.1, "qr": 0.05},
  "monthly_trend": [{"month": "2026-07", "count": 210}],
  "share_stats": {"total_shares": 45, "by_style": {"MAP_AND_DNA": 20, "MAP": 15, "DNA": 10}}
}
```
(`visit_stats.monthly`와 `monthly_trend`는 사실상 같은 데이터라 최종 스키마에서는 하나로 합칠 수 있음 — 구현 단계에서 정리)

**집계 근거 테이블**:
| 통계 | 근거 테이블 |
|------|------|
| 방문 인증·월별 추이 | `quest_progress`(status=completed) + `quests.region_id` |
| 인기 관광지 | `quest_progress` × `quests` 조인 후 quest별 count |
| DNA 분포 | `quest_progress`로 해당 지역 방문자 user_id 추출 → `users.dna` 집계 |
| 여정 완주 통계 | `journeys`(status, start_date, completed_at) |
| 인증 방식별 참여율 | `quest_progress` × `quests.mission_type` |
| 공유 통계 | `shares`(region 연결이 없어 사용자의 대표 지역 산정 필요 — 의사결정 참고) |

## 의사결정 (함께 논의 · 근거 필수)

| 결정할 항목 | 선택지 | 제안 / 근거 | 상태 |
|------|--------|------------|------|
| 인증 방식 | A) API 키(서비스키 쿼리파라미터)<br>B) 완전 공개(키 없음) | **A 선택** — TourAPI와 같은 관례라 지자체 담당자에게 익숙하고, 누가 얼마나 호출하는지 추적·회수가 가능하다. | 합의됨 |
| 키 저장 방식 | A) `.env`에 정적 키 목록<br>B) DB 테이블(`open_api_keys`)로 발급·회수 관리 | **B 선택** — 여러 지자체에 개별 발급·회수해야 하는 실사용 시나리오라, 배포 없이 키를 추가/폐기할 수 있어야 한다. | 합의됨 |
| 범위 | A) 일부 카테고리만 우선<br>B) 7개 전부 한 번에 | **B 선택**(사용자 결정) | 합의됨 |
| 지역별 접근 제한 | A) 키마다 특정 지역만 허용<br>B) 키 하나로 전 지역 조회 | **B 선택**(사용자 결정 — "오픈API처럼 지역 선택하면 가져오는 형태") | 합의됨 |
| 공유 통계의 지역 연결 | A) `Share`에 region 컬럼 추가<br>B) 사용자의 `MapProgress` 중 완료 수 최대인 지역을 "대표 지역"으로 근사 | **A 선택**(사용자 결정) — 근사치보다 정확한 데이터를 우선한다. 공유 생성 시점에 그 유저의 가장 진행률 높은 지역(또는 가장 최근 채색된 지역)을 `region_id`로 함께 저장한다(구체적 산정 기준은 공유 통계 구현 단위에서 확정). | 합의됨 |

## 영향 범위
* `backend/app/open_api/`: 신규(`models.py`, `schemas.py`, `repository.py`, `service.py`, `router.py`)
* `backend/app/main.py`: 신규 라우터 등록(`/api/v1/open` prefix)
* `backend/app/shares/models.py`: `Share`에 `region_id`(nullable FK) 추가
* `backend/app/shares/service.py`: 공유 생성 시 `region_id` 산정·저장 로직 추가
* `backend/alembic/versions/`: `open_api_keys` 테이블 + `shares.region_id` 컬럼 마이그레이션
* `backend/scripts/`: 키 발급용 CLI 스크립트(예: `issue_open_api_key.py`, `generate_dev_token.py`와 같은 패턴)

## 작업 단계
- [ ] 1. 문서 작성 및 사용자 컨펌(공유 통계 지역 연결 방식 결정 포함)
- [ ] 2. `open_api_keys` 테이블·마이그레이션, 키 발급 스크립트, 인증 dependency
- [ ] 3. 쉬운 통계부터 구현: 방문 인증·월별 추이, 인기 관광지, 인증 방식별 참여율
- [ ] 4. 나머지 통계: DNA 분포, 여정 완주 통계, 공유 통계
- [ ] 5. 테스트(정상 조회·잘못된 키·존재하지 않는 지역) 및 문서화

## 리스크 / 미해결 질문
* 공유 통계의 지역 연결 방식(위 의사결분 표 참고) — 근사치로 갈지 스키마를 바꿀지 결정 필요.
* 표본이 매우 작은 지역(예: 특정 달에 완료 1~2건)은 통계가 사실상 개인 식별에 가까워질 수 있음 — 이번 범위에서는 막지 않지만 알려진 한계로 남긴다.
* 요청량 제한이 없어 키가 유출되면 과도한 조회가 가능 — 후속 과제.
