/// 닉네임 미설정 시 화면 전반(마이·내 정보 수정)에서 공통으로 쓰는 기본값.
const kDefaultNickname = '여행자닉네임';

/// 타임라인 항목 — 완료한 퀘스트 1건의 기록.
class TimelineEntry {
  const TimelineEntry({
    required this.questId,
    required this.date,
    required this.month,
  });

  final String questId;
  final String date;
  final String month;
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
    required this.regionProgress,
    required this.timeline,
    required this.dnaType,
    required this.tripQuests,
    required this.tripInfo,
    required this.nickname,
  });

  const ProgressState.empty()
    : completedQuestIds = const {},
      regionProgress = const {},
      timeline = const [],
      dnaType = null,
      tripQuests = const {},
      tripInfo = const {},
      nickname = null;

  final Set<String> completedQuestIds;
  final Map<String, int> regionProgress;
  final List<TimelineEntry> timeline;
  final String? dnaType;

  /// 지역별로 "여행 시작하기"에서 고른 퀘스트 id 목록([RegionQuestSelectScreen] 다중 선택).
  final Map<String, Set<String>> tripQuests;

  /// 지역별 여행 이름·기간 — 여행 시작 시 입력([TripInfo]).
  final Map<String, TripInfo> tripInfo;

  /// 사용자가 내 정보 수정에서 설정한 닉네임(없으면 [kDefaultNickname] 표시).
  final String? nickname;

  bool isCompleted(String questId) => completedQuestIds.contains(questId);

  int progressOf(String regionId) => regionProgress[regionId] ?? 0;

  int get completedRegionCount =>
      regionProgress.values.where((count) => count > 0).length;

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
    Map<String, int>? regionProgress,
    List<TimelineEntry>? timeline,
    String? dnaType,
    Map<String, Set<String>>? tripQuests,
    Map<String, TripInfo>? tripInfo,
    String? nickname,
  }) {
    return ProgressState(
      completedQuestIds: completedQuestIds ?? this.completedQuestIds,
      regionProgress: regionProgress ?? this.regionProgress,
      timeline: timeline ?? this.timeline,
      dnaType: dnaType ?? this.dnaType,
      tripQuests: tripQuests ?? this.tripQuests,
      tripInfo: tripInfo ?? this.tripInfo,
      nickname: nickname ?? this.nickname,
    );
  }
}
