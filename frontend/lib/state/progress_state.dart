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
  });

  final String questId;
  final DateTime completedAt;

  /// 사진 인증 퀘스트를 완료할 때 사용자가 실제로 선택한 사진(세션 동안만 메모리에 보관 —
  /// 백엔드 연동 전까지는 서버에 저장되지 않는다, KAN-46 히스토리 피드백).
  final Uint8List? photo;

  static String _two(int n) => n.toString().padLeft(2, '0');

  String get date =>
      '${completedAt.year}.${_two(completedAt.month)}.${_two(completedAt.day)}';

  String get month => '${completedAt.year}년 ${completedAt.month}월';

  String get time => '${_two(completedAt.hour)}:${_two(completedAt.minute)}';
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
    required this.nickname,
    required this.regionProgress,
  });

  const ProgressState.empty()
    : completedQuestIds = const {},
      timeline = const [],
      dnaType = null,
      tripQuests = const {},
      nickname = null,
      regionProgress = const {};

  final Set<String> completedQuestIds;
  final List<TimelineEntry> timeline;
  final String? dnaType;

  /// 지역별로 "여행 시작하기"에서 고른 퀘스트 id 목록([RegionQuestSelectScreen] 다중 선택).
  final Map<String, Set<String>> tripQuests;

  /// 사용자가 내 정보 수정에서 설정한 닉네임(없으면 [kDefaultNickname] 표시).
  final String? nickname;

  /// 지역별 완료 퀘스트 개수 — 로컬 완료 시 즉시 +1(낙관적 갱신), 앱 진입 시 백엔드
  /// (`GET /users/me/map`)의 completed_count로 덮어써 동기화한다([020-frontend-map-sync],
  /// `ProgressNotifier.syncRegionProgressFromServer`).
  final Map<String, int> regionProgress;

  bool isCompleted(String questId) => completedQuestIds.contains(questId);

  /// 완료 기록(시각·사진) 조회 — 퀘스트 상세의 "히스토리 보기"에서 사용한다.
  TimelineEntry? timelineEntryFor(String questId) {
    for (final entry in timeline) {
      if (entry.questId == questId) return entry;
    }
    return null;
  }

  /// 완료 개수가 이 값 이상이면 채도 100% — 지역별 퀘스트 개수가 제각각이라(1개~3개)
  /// 지역 전체 개수 대비 비율로 계산하면 퀘스트가 적은 지역만 쉽게 꽉 차버리는 문제가 있어,
  /// 모든 지역에 같은 기준선을 쓴다. `completed_count`는 재방문 시 계속 늘어날 수 있어
  /// 정적 퀘스트 개수와 무관하다(KAN-46).
  static const _saturationCap = 6;

  /// 지역의 채색 진하기(0.0~1.0) — 그 지역 완료 퀘스트 개수([regionProgress], 백엔드
  /// completed_count와 동기화)를 [_saturationCap]으로 나눈 비율이다.
  double regionSaturation(String regionId) {
    final completed = regionProgress[regionId] ?? 0;
    return (completed / _saturationCap).clamp(0.0, 1.0);
  }

  /// 완전히 채색된(채도 100%) 지역 수 — "완료 지역" 통계에서 쓴다.
  int get completedRegionCount =>
      kRegions.where((r) => regionSaturation(r.id) >= 1.0).length;

  /// 지역의 여행 시작 시 선택한 퀘스트 목록(없으면 빈 집합).
  Set<String> tripQuestsOf(String regionId) => tripQuests[regionId] ?? const {};

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
    String? nickname,
    Map<String, int>? regionProgress,
  }) {
    return ProgressState(
      completedQuestIds: completedQuestIds ?? this.completedQuestIds,
      timeline: timeline ?? this.timeline,
      dnaType: dnaType ?? this.dnaType,
      tripQuests: tripQuests ?? this.tripQuests,
      nickname: nickname ?? this.nickname,
      regionProgress: regionProgress ?? this.regionProgress,
    );
  }
}
