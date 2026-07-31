/// 지도 채색 기준 전환(완료 퀘스트 개수 → 완료 여행 수) 검증
/// ([docs/specs/035-journey-map-coloring]).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:colortrip/state/progress_notifier.dart';
import 'package:colortrip/state/progress_state.dart';

void main() {
  group('ProgressState.regionSaturation — 완료 여행 수 기반', () {
    test('완료 여행 0회면 미채색(0.0)이고 완료 지역 통계도 0이다', () {
      const state = ProgressState.empty();
      expect(state.completedTripCountOf('cheongju'), 0);
      expect(state.regionSaturation('cheongju'), 0.0);
      expect(state.completedRegionCount, 0);
    });

    test('완료 여행 1회부터 채색이 시작되고(1/3) 완료 지역으로 센다', () {
      final state = const ProgressState.empty().copyWith(
        regionTripCount: {'cheongju': 1},
      );
      expect(state.regionSaturation('cheongju'), closeTo(1 / 3, 1e-9));
      expect(state.completedRegionCount, 1);
    });

    test('기준선(3회) 이상이면 최대 채도(1.0)로 고정된다', () {
      final state = const ProgressState.empty().copyWith(
        regionTripCount: {'cheongju': 3, 'danyang': 5},
      );
      expect(state.regionSaturation('cheongju'), 1.0);
      expect(state.regionSaturation('danyang'), 1.0);
      expect(state.completedRegionCount, 2);
    });

    test('서버 동기화 값이 로컬 완주 횟수보다 크면 서버 값을 쓴다(max 병합)', () {
      final state = const ProgressState.empty().copyWith(
        localTripCompletions: {'danyang': 1},
        regionTripCount: {'danyang': 2},
      );
      expect(state.completedTripCountOf('danyang'), 2);
      expect(state.regionSaturation('danyang'), closeTo(2 / 3, 1e-9));
    });

    test('진행 중(미완주) 여행은 서버 값이 없으면 채색하지 않는다', () {
      final state = const ProgressState.empty().copyWith(
        tripQuests: {
          'danyang': {'dy1', 'dy2'},
        },
        completedQuestIds: {'dy1'},
      );
      expect(state.tripStatusOf('danyang'), RegionTripStatus.inProgress);
      expect(state.completedTripCountOf('danyang'), 0);
      expect(state.regionSaturation('danyang'), 0.0);
    });

    test('완료 퀘스트 개수(regionProgress)는 더 이상 채색에 영향을 주지 않는다', () {
      final state = const ProgressState.empty().copyWith(
        regionProgress: {'cheongju': 6},
      );
      expect(state.regionSaturation('cheongju'), 0.0);
      expect(state.completedRegionCount, 0);
    });
  });

  group('ProgressNotifier.completeQuest — 로컬 완주 누적', () {
    /// 단양 여행을 [questIds]로 시작한 컨테이너.
    ProviderContainer startDanyangTrip(Set<String> questIds) {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(progressProvider.notifier)
          .setTripQuests('danyang', questIds);
      return container;
    }

    test('여행을 완주하면 서버 값이 없어도 1회로 계산된다', () {
      final container = startDanyangTrip({'dy1'});
      container.read(progressProvider.notifier).completeQuest('dy1');

      final state = container.read(progressProvider);
      expect(state.localTripCompletions['danyang'], 1);
      expect(state.completedTripCountOf('danyang'), 1);
      expect(state.regionSaturation('danyang'), closeTo(1 / 3, 1e-9));
      expect(state.completedRegionCount, 1);
    });

    test('완주한 지역에 퀘스트를 더 담아도 이미 칠한 채색이 사라지지 않는다', () {
      // KAN-46 재방문 흐름 — 완주 후 "퀘스트 더 선택하기"로 선택 집합이 교체되면
      // 현재 집합은 다시 미완료가 되지만, 누적 완주 횟수는 유지되어야 한다.
      final container = startDanyangTrip({'dy1'});
      final notifier = container.read(progressProvider.notifier);
      notifier.completeQuest('dy1');
      notifier.setTripQuests('danyang', {'dy1', 'dy2'});

      final afterAdd = container.read(progressProvider);
      expect(afterAdd.tripStatusOf('danyang'), RegionTripStatus.inProgress);
      expect(afterAdd.completedTripCountOf('danyang'), 1);
      expect(afterAdd.regionSaturation('danyang'), closeTo(1 / 3, 1e-9));
      expect(afterAdd.completedRegionCount, 1);

      // 추가한 퀘스트까지 완료하면 재방문 완주로 1회 더 누적된다.
      notifier.completeQuest('dy2');
      final afterSecond = container.read(progressProvider);
      expect(afterSecond.completedTripCountOf('danyang'), 2);
      expect(afterSecond.regionSaturation('danyang'), closeTo(2 / 3, 1e-9));
    });

    test('여행을 시작하지 않은 채 완료한 퀘스트는 완주로 세지 않는다', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(progressProvider.notifier).completeQuest('dy1');

      final state = container.read(progressProvider);
      expect(state.tripStatusOf('danyang'), RegionTripStatus.notStarted);
      expect(state.completedTripCountOf('danyang'), 0);
      expect(state.regionSaturation('danyang'), 0.0);
    });
  });

  group('ProgressNotifier.syncRegionProgressFromServer — 여행 수 동기화', () {
    test('퀘스트 수와 여행 수를 함께 반영하고, 응답에 없는 지역은 유지한다', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(progressProvider.notifier);

      notifier.syncRegionProgressFromServer(
        {'cheongju': 4},
        serverRegionTripCount: {'cheongju': 2},
      );
      notifier.syncRegionProgressFromServer(
        {'danyang': 1},
        serverRegionTripCount: {'danyang': 1},
      );

      final state = container.read(progressProvider);
      expect(state.regionProgress['cheongju'], 4);
      expect(state.regionTripCount['cheongju'], 2);
      expect(state.regionTripCount['danyang'], 1);
      expect(state.regionSaturation('cheongju'), closeTo(2 / 3, 1e-9));
      expect(state.completedRegionCount, 2);
    });
  });
}
