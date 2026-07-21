# [계획] 여행 공유 카드 API 구현

| 항목 | 내용 |
|------|------|
| 기능명 | 여행 공유 카드 API |
| Spec 폴더 | `docs/specs/030-share-card/` |
| 영역 | backend |
| 작성자 | Antigravity (AI) |
| 작성일 | 2026-07-21 |
| 상태 | 계획 |

## 배경 / 목적
* 사용자가 자신이 색칠한 충북 지역 지도와 여행 DNA 상태를 카드로 시각화하고, 이를 외부(카카오톡, SNS 등)로 공유할 수 있는 **공유 카드 시스템**이 필요합니다.
* 카드 미리보기용 내 공유 데이터 요약 조회, 공유 숏링크 및 코드 생성, 비인증 사용자가 외부에서 공유 카드를 조회할 수 있는 공개 API를 개발합니다.

## 목표 (Goals)
* `shares` 데이터베이스 테이블 설계 및 Alembic 마이그레이션 적용.
* **미리보기 요약 API**: `GET /api/v1/users/me/share-summary` (완료 지역 수, 진행률 %, DNA, 색칠 시·군 목록 반환).
* **공유 코드 생성 API**: `POST /api/v1/shares` (스타일: `MAP_AND_DNA`, `MAP`, `DNA`).
* **공개 공유 카드 조회 API**: `GET /api/v1/shares/{share_code}` (비인증 공개 접근 허용, 외부 조회용 데이터 반환).

## 비목표 (Non-Goals)
* 프론트엔드 (Flutter) 공유 카드 UI/UX 화면 구현 (백엔드 API 및 연동 검증 위주).
* 외부 웹 랜딩 SSR 서버 렌더링 (이번 스펙은 REST API JSON 서빙 중심).

## 요구사항
* `share_style` 값은 `MAP_AND_DNA`, `MAP`, `DNA` 3가지 Enum 값을 사용합니다.
* `GET /api/v1/shares/{share_code}`는 비인증(Public)으로 누구나 조회할 수 있어야 합니다.
* `share_code`는 중복되지 않는 고유 숏코드(예: 8자리 알파벳/숫자 혼합 문자열)로 생성되어야 합니다.

## 의사결정 (함께 논의 · 근거 필수)

| 결정할 항목 | 선택지 | 제안 / 근거 | 상태 |
|------|--------|------------|------|
| **공유 스타일 파라미터 규격** | A) `MAP_AND_DNA`, `MAP_ONLY`, `DNA_ONLY`<br>B) `MAP_AND_DNA`, `MAP`, `DNA` | **B) `MAP_AND_DNA`, `MAP`, `DNA` 선택**<br>- 사용자 요청 사항 준수 및 명확하고 직관적인 값 사용. | 합의됨 |
| **공유 숏코드 생성 방식** | A) UUID 전체 문자열<br>B) `secrets.token_urlsafe(6)` 기반 8자리 무작위 숏코드 | **B) 8자리 무작위 숏코드 선택**<br>- URL이 짧고 카카오톡/SNS 공유 시 미관상 좋음.<br>- 데이터베이스 Unique 인덱스를 통해 중복 시 재시도 로직 적용. | 합의됨 |

## 영향 범위
* `backend/app/main.py`: 공유 라우터 추가 등록
* `backend/app/shares/`: [NEW] 신규 패키지 및 모듈 구성 (`models.py`, `schemas.py`, `repository.py`, `service.py`, `router.py`)
* `backend/alembic/versions/`: [NEW] alembic 마이그레이션 파일 추가

## 작업 단계
- [ ] 1. Alembic 데이터베이스 마이그레이션 생성 및 `shares` 테이블 스키마 정의
- [ ] 2. `app/shares/` 모듈 구현 (`models`, `schemas`, `repository`, `service`, `router`)
- [ ] 3. `GET /users/me/share-summary`, `POST /shares`, `GET /shares/{share_code}` 라우터 구축
- [ ] 4. 단위 및 통합 테스트 코드 작성 및 검증 (`backend/tests/test_shares.py`)
