import 'dart:math' as math;
import 'dart:typed_data';

import '../data/static/regions_data.dart';

/// 닉네임 미설정 시 화면 전반(마이·내 정보 수정)에서 공통으로 쓰는 기본값.
const kDefaultNickname = '여행자닉네임';

/// 타임라인 항목 — 완료한 퀘스트 1건의 기록. `date`/`month` 문자열을 따로 들고 있으면
/// 포맷을 맞추다 어긋나기 쉬워(과거 "2026.010.15" 같은 버그가 있었다), 시각(completedAt) 하나만
/// 저장하고 표시용 문자열은 그때그때 계산한다.
class TimelineEntry {
  const TimelineEntry({
    required this.questId,
    required this.completedAt,
    this.photo,
    this.photoUrl,
  });

  final String questId;
  final DateTime completedAt;

  /// 사진 인증 퀘스트를 완료할 때 사용자가 실제로 선택한 사진(세션 동안만 메모리에 보관 —
  /// 백엔드 연동 전까지는 서버에 저장되지 않는다, KAN-46 히스토리 피드백).
  final Uint8List? photo;
  final String? photoUrl;

  static String _two(int n) => n.toString().padLeft(2, '0');

  String get date =>
      '${completedAt.year}.${_two(completedAt.month)}.${_two(completedAt.day)}';

  String get month => '${completedAt.year}년 ${completedAt.month}월';

  String get time => '${_two(completedAt.hour)}:${_two(completedAt.minute)}';
}

/// 여행 메타 정보 — "여행 시작하기" 시트에서 입력받는 이름·기간(2026-07-16 KAN-28).
/// 백엔드 journeys.title/start_date/end_date에 대응한다.
class TripInfo {
  const TripInfo({
    required this.name,
    required this.startDate,
    required this.endDate,
  });

  final String name;
  final DateTime startDate;
  final DateTime endDate;

  /// "2026.07.20 ~ 07.22" — 여행 목록 카드의 기간 표기(같은 해면 연도 생략).
  String get periodLabel => formatPeriod(startDate, endDate);

  static String formatPeriod(DateTime startDate, DateTime endDate) {
    String md(DateTime d) =>
        '${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
    final start = '${startDate.year}.${md(startDate)}';
    final end = endDate.year == startDate.year
        ? md(endDate)
        : '${endDate.year}.${md(endDate)}';
    return '$start ~ $end';
  }
}

/// 지역의 "여행" 진행 상태 — [progressState.tripQuests] 기준(2026-07-09, "여행 시작하기" 도입).
enum RegionTripStatus {
  /// 여행 시작 전 (선택한 퀘스트 없음).
  notStarted,

  /// 여행 시작함, 선택한 퀘스트 중 미완료가 남아있음.
  inProgress,

  /// 여행 시작함, 선택한 퀘스트를 전부 완료함.
  completed,
}

/// 앱 전역 진행 상태 — 프로토타입 Component.state(completed/progress/timeline/dnaType)를 옮김.
/// 백엔드 연동 전까지 메모리에서만 관리된다(앱 재실행 시 초기화, [plan.md] 의사결정).
class ProgressState {
  const ProgressState({
    required this.completedQuestIds,
    required this.timeline,
    required this.dnaType,
    required this.tripQuests,
    required this.tripInfo,
    required this.nickname,
    required this.regionProgress,
    required this.regionTripCount,
    required this.localTripCompletions,
  });

  const ProgressState.empty()
    : completedQuestIds = const {},
      timeline = const [],
      dnaType = null,
      tripQuests = const {},
      tripInfo = const {},
      nickname = null,
      regionProgress = const {},
      regionTripCount = const {},
      localTripCompletions = const {};

  final Set<String> completedQuestIds;
  final List<TimelineEntry> timeline;
  final String? dnaType;

  /// 지역별로 "여행 시작하기"에서 고른 퀘스트 id 목록([RegionQuestSelectScreen] 다중 선택).
  final Map<String, Set<String>> tripQuests;

  /// 지역별 여행 이름·기간 — 여행 시작 시 입력([TripInfo]).
  final Map<String, TripInfo> tripInfo;

  /// 사용자가 내 정보 수정에서 설정한 닉네임(없으면 [kDefaultNickname] 표시).
  final String? nickname;

  /// 지역별 완료 퀘스트 개수 — 로컬 완료 시 즉시 +1(낙관적 갱신), 앱 진입 시 백엔드
  /// (`GET /users/me/map`)의 completed_count로 덮어써 동기화한다([020-frontend-map-sync],
  /// `ProgressNotifier.syncRegionProgressFromServer`). 지도 채색 기준에서는 빠졌지만
  /// ([055-journey-map-coloring]) 다른 통계·동기화에 그대로 쓰여 유지한다.
  final Map<String, int> regionProgress;

  /// 지역별 완료 여행(여정) 수 — 백엔드(`GET /users/me/map`)의 completed_journey_count와
  /// 동기화한 서버 값이다([055-journey-map-coloring]). 로컬에서 막 완주한 여행은
  /// [completedTripCountOf]가 max 병합으로 반영하므로 여기에는 서버 값만 담는다.
  final Map<String, int> regionTripCount;

  /// 지역별 로컬 누적 완주 횟수 — 여행을 완주한 **시점에** 1씩 늘린다
  /// (`ProgressNotifier.completeQuest`). 현재 선택 집합의 완주 여부로 파생하지 않는 이유:
  /// 완료한 지역에 퀘스트를 더 담으면(KAN-46 재방문) 선택 집합이 다시 미완료가 되어
  /// 이미 칠해진 채색이 사라지기 때문이다([055-journey-map-coloring]).
  final Map<String, int> localTripCompletions;

  bool isCompleted(String questId) => completedQuestIds.contains(questId);

  /// 완료 기록(시각·사진) 조회 — 퀘스트 상세의 "히스토리 보기"에서 사용한다.
  TimelineEntry? timelineEntryFor(String questId) {
    for (final entry in timeline) {
      if (entry.questId == questId) return entry;
    }
    return null;
  }

  /// 완료 여행 수가 이 값 이상이면 채도 100% — 퀘스트 기준(6개)일 때와 같은 이유로 모든
  /// 지역에 같은 기준선을 쓴다. 지도가 채도를 **5단계**로 양자화해 칠하므로
  /// (`mapFillColors`, KAN-51) cap도 5로 맞춰 여행 1회가 정확히 한 단계씩 진해지게 한다 —
  /// cap이 3이면 5단계 중 2개가 쓰이지 않는다([055-journey-map-coloring] 의사결정).
  static const _tripSaturationCap = 5;

  /// 지역에서 완료한 여행 수(표시용) — 서버 동기화 값([regionTripCount])과 로컬 누적
  /// 완주 횟수([localTripCompletions])의 max 병합이다. FE 정적 퀘스트 완료는 서버에
  /// 기록되지 않아 서버 값으로 덮어쓰면 로컬 채색이 사라지기 때문이다
  /// ([055-journey-map-coloring] 의사결정).
  int completedTripCountOf(String regionId) {
    return math.max(
      regionTripCount[regionId] ?? 0,
      localTripCompletions[regionId] ?? 0,
    );
  }

  /// 지역의 채색 진하기(0.0~1.0) — 그 지역에서 완료한 여행 수([completedTripCountOf])를
  /// [_tripSaturationCap]으로 나눈 비율이다. "여행을 완주할수록 지역이 진해지는" 경험을
  /// 위해 완료 퀘스트 개수 기준에서 전환했다([055-journey-map-coloring]).
  double regionSaturation(String regionId) {
    return (completedTripCountOf(regionId) / _tripSaturationCap).clamp(
      0.0,
      1.0,
    );
  }

  /// 여행을 1회 이상 완료한 지역 수 — "완료 지역" 통계에서 쓴다. 채도 100%(cap회) 기준은
  /// "한 번이라도 완주한 지역"이라는 직관에 비해 과도하게 엄격해 1회 이상으로 정의한다
  /// ([055-journey-map-coloring] 의사결정).
  int get completedRegionCount =>
      kRegions.where((r) => completedTripCountOf(r.id) >= 1).length;

  /// 지역의 여행 시작 시 선택한 퀘스트 목록(없으면 빈 집합).
  Set<String> tripQuestsOf(String regionId) => tripQuests[regionId] ?? const {};

  /// 지역의 여행 이름·기간(여행 시작 전이면 null).
  TripInfo? tripInfoOf(String regionId) => tripInfo[regionId];

  RegionTripStatus tripStatusOf(String regionId) {
    final trip = tripQuestsOf(regionId);
    if (trip.isEmpty) return RegionTripStatus.notStarted;
    final allDone = trip.every(isCompleted);
    return allDone ? RegionTripStatus.completed : RegionTripStatus.inProgress;
  }

  ProgressState copyWith({
    Set<String>? completedQuestIds,
    List<TimelineEntry>? timeline,
    String? dnaType,
    Map<String, Set<String>>? tripQuests,
    Map<String, TripInfo>? tripInfo,
    String? nickname,
    Map<String, int>? regionProgress,
    Map<String, int>? regionTripCount,
    Map<String, int>? localTripCompletions,
  }) {
    return ProgressState(
      completedQuestIds: completedQuestIds ?? this.completedQuestIds,
      timeline: timeline ?? this.timeline,
      dnaType: dnaType ?? this.dnaType,
      tripQuests: tripQuests ?? this.tripQuests,
      tripInfo: tripInfo ?? this.tripInfo,
      nickname: nickname ?? this.nickname,
      regionProgress: regionProgress ?? this.regionProgress,
      regionTripCount: regionTripCount ?? this.regionTripCount,
      localTripCompletions: localTripCompletions ?? this.localTripCompletions,
    );
  }
}
