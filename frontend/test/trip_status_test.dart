/// 여행 진행/완료 판정 검증 — 서버 `Journey.status`와 같은 규칙을 FE projection에서도 쓴다
/// ([docs/specs/010-journey/description.md] "여정 완료 판정", KAN-73).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:colortrip/data/repositories/domain_repository.dart';
import 'package:colortrip/state/progress_notifier.dart';
import 'package:colortrip/state/progress_state.dart';

void main() {
  /// 단양 여행을 [questIds]와 기간(오늘 기준 [endOffsetDays])으로 시작한 컨테이너.
  ProviderContainer startDanyangTrip(
    Set<String> questIds, {
    required int endOffsetDays,
  }) {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final today = DateTime(2026, 8, 13);
    container
        .read(progressProvider.notifier)
        .startTrip(
          'danyang',
          questIds,
          TripInfo(
            name: '단양 여행',
            startDate: today.subtract(const Duration(days: 3)),
            endDate: today.add(Duration(days: endOffsetDays)),
          ),
        );
    return container;
  }

  final today = DateTime(2026, 8, 13);

  test('기간이 지났고 완료 퀘스트가 1개 이상이면 완료로 본다', () {
    final container = startDanyangTrip({'dy1', 'dy2'}, endOffsetDays: -2);
    container.read(progressProvider.notifier).completeQuest('dy1');

    final state = container.read(progressProvider);
    expect(
      state.tripStatusOf('danyang', now: today),
      RegionTripStatus.completed,
    );
  });

  test('기간이 지났어도 완료 퀘스트가 0개면 진행중이다', () {
    final container = startDanyangTrip({'dy1', 'dy2'}, endOffsetDays: -2);

    final state = container.read(progressProvider);
    expect(
      state.tripStatusOf('danyang', now: today),
      RegionTripStatus.inProgress,
    );
  });

  test('기간이 남아 있으면 부분 완료는 진행중이다', () {
    final container = startDanyangTrip({'dy1', 'dy2'}, endOffsetDays: 5);
    container.read(progressProvider.notifier).completeQuest('dy1');

    final state = container.read(progressProvider);
    expect(
      state.tripStatusOf('danyang', now: today),
      RegionTripStatus.inProgress,
    );
  });

  test('마지막 날에는 아직 진행중이고, 하루 지나면 완료가 된다', () {
    final container = startDanyangTrip({'dy1', 'dy2'}, endOffsetDays: 0);
    container.read(progressProvider.notifier).completeQuest('dy1');
    final state = container.read(progressProvider);

    expect(
      state.tripStatusOf('danyang', now: today),
      RegionTripStatus.inProgress,
    );
    expect(
      state.tripStatusOf('danyang', now: today.add(const Duration(days: 1))),
      RegionTripStatus.completed,
    );
  });

  test('퀘스트를 전부 완료하면 기간과 무관하게 완료다', () {
    final container = startDanyangTrip({'dy1'}, endOffsetDays: 30);
    container.read(progressProvider.notifier).completeQuest('dy1');

    final state = container.read(progressProvider);
    expect(
      state.tripStatusOf('danyang', now: today),
      RegionTripStatus.completed,
    );
  });

  test('여행을 시작하지 않은 지역은 notStarted다', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(progressProvider).tripStatusOf('danyang', now: today),
      RegionTripStatus.notStarted,
    );
  });

  test('서버 스냅샷의 completed 여정 수를 여행 완료 지표로 쓴다', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final createdAt = DateTime(2026, 8, 13);

    container
        .read(progressProvider.notifier)
        .replaceFromServer(
          DomainSnapshot(
            catalog: const DomainCatalog(
              regionIdsByKey: {'danyang': 'region-uuid'},
              regionKeysById: {'region-uuid': 'danyang'},
              questIdsByKey: {'dy1': 'quest-uuid'},
              questKeysById: {'quest-uuid': 'dy1'},
            ),
            journeys: [
              DomainJourney(
                id: 'completed-journey',
                regionKey: 'danyang',
                questKeys: const ['dy1'],
                title: '완료 여행',
                startDate: createdAt,
                endDate: createdAt,
                status: 'completed',
                createdAt: createdAt,
              ),
              DomainJourney(
                id: 'active-journey',
                regionKey: 'danyang',
                questKeys: const ['dy1'],
                title: '진행 여행',
                startDate: createdAt,
                endDate: createdAt.add(const Duration(days: 1)),
                status: 'in_progress',
                createdAt: createdAt,
              ),
            ],
            completedQuestKeys: const {},
            regionProgress: const {},
            regionTripCount: const {},
            timeline: const [],
          ),
        );

    expect(container.read(progressProvider).completedJourneyCount, 1);
  });
}
