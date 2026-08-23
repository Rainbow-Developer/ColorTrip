# [설명] 여행 관리

## 개요
여행 관리는 사용자가 이미 만든 여행의 이름과 일정을 수정하고, 필요 없어진 여행을 삭제하는 기능이다. 여행 목록의 카드 액션 메뉴에서 시작하며, 카드 탭으로 여행 상세에 들어가는 기존 흐름은 유지한다.

## 동작 방식
여행 목록에서 카드의 메뉴 버튼을 누르면 `여행 정보 수정`과 `여행 삭제` 액션이 열린다. 수정은 여행 생성 시 사용하던 이름·기간 입력 시트를 재사용해 저장하고, 삭제는 확인 다이얼로그를 거친 뒤 서버에 삭제 요청을 보낸다.

여행 기간은 서버에서 최종 검증한다. 종료일이 시작일보다 빠르거나 이미 지난 기간이면 저장할 수 없고,
같은 사용자의 삭제되지 않은 다른 여행과 날짜 범위가 겹쳐도 저장할 수 없다.

삭제된 여행은 여행 목록과 상세 진입 대상에서 제외된다. 해당 여행에 연결된 퀘스트 진행·완료 기록과 타임라인 이벤트도 soft delete되어 지도 채색과 기록 화면에서 사라진다.

## 주요 구성 요소 / 위치

| 구성 요소 | 역할 | 위치 |
|-----------|------|------|
| Journeys API | 여행 수정·삭제 엔드포인트 | `backend/app/journeys/router.py` |
| Journeys service | 소유권 확인, soft delete, 상태 재계산 | `backend/app/journeys/service.py` |
| Domain repository/controller | Flutter API 호출과 스냅샷 갱신 | `frontend/lib/data/repositories/domain_repository.dart`, `frontend/lib/state/domain_controller.dart` |
| Trip info sheet | 여행명·일정 입력 공용 시트 | `frontend/lib/core/widgets/trip_info_sheet.dart` |
| Travel list | 여행 카드 액션 메뉴 연결 | `frontend/lib/features/travel/travel_list_screen.dart` |

## 설정 / 사용법
추가 환경변수는 없다. 기존 인증된 `/api/v1` 세션을 사용한다.

## 예시
- 여행 목록 > 진행중인 여행 카드 `⋮` > `여행 정보 수정` > 이름/기간 변경 > 저장
- 여행 목록 > 지난 여행 카드 `⋮` > `여행 삭제` > 확인 > 목록에서 제거

## 관련 문서
- `docs/specs/010-journey/`
- `docs/specs/040-domain-state-persistence/`
- `README.md`
