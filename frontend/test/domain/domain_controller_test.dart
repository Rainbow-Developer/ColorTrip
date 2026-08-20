import 'dart:typed_data';

import 'package:colortrip/data/repositories/domain_repository.dart';
import 'package:colortrip/data/static/quests_data.dart';
import 'package:colortrip/state/domain_controller.dart';
import 'package:colortrip/state/progress_notifier.dart';
import 'package:colortrip/state/progress_state.dart';
import 'package:colortrip/state/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _catalog = DomainCatalog(
  regionIdsByKey: {'danyang': 'region-uuid'},
  regionKeysById: {'region-uuid': 'danyang'},
  questIdsByKey: {'dy1': 'quest-uuid'},
  questKeysById: {'quest-uuid': 'dy1'},
);

DomainSnapshot _snapshot({bool completed = true}) => DomainSnapshot(
  catalog: _catalog,
  journeys: [
    DomainJourney(
      id: 'journey-uuid',
      regionKey: 'danyang',
      questKeys: const ['dy1'],
      title: '단양 여행',
      startDate: DateTime(2026, 7, 20),
      endDate: DateTime(2026, 7, 22),
      status: completed ? 'completed' : 'in_progress',
      createdAt: DateTime(2026, 7, 20),
    ),
  ],
  completedQuestKeys: completed ? {'dy1'} : {},
  regionProgress: {'danyang': completed ? 1 : 0},
  regionTripCount: {'danyang': completed ? 1 : 0},
  timeline: completed
      ? [
          DomainTimelineEntry(
            questKey: 'dy1',
            occurredAt: DateTime(2026, 7, 21, 10),
            photoUrl: '/uploads/photos/x.jpg',
          ),
        ]
      : const [],
);

class _Repository implements DomainRepository {
  DomainSnapshot snapshot = _snapshot();
  Object? createError;
  Object? fetchError;
  int fetchCalls = 0;
  int createCalls = 0;
  final createRequestIds = <String>[];
  String? replacedJourneyId;
  String? updatedJourneyId;
  String? deletedJourneyId;

  @override
  Future<DomainSnapshot> fetchSnapshot() async {
    fetchCalls++;
    if (fetchError case final error?) throw error;
    return snapshot;
  }

  @override
  Future<List<DomainRecommendedRegion>>
  fetchUnvisitedRecommendedRegions() async => const [];

  @override
  Future<List<String>> fetchRecommendedQuestKeys({String? category, 
    required String regionKey,
    int size = 2,
  }) async => const [];

  @override
  Future<DomainJourney> createJourney({
    required String clientRequestId,
    required String regionKey,
    required List<String> questKeys,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    createCalls++;
    createRequestIds.add(clientRequestId);
    if (createError case final error?) throw error;
    snapshot = _snapshot(completed: false);
    return snapshot.journeys.single;
  }

  @override
  Future<DomainJourney> replaceJourneyQuests({
    required String journeyId,
    required List<String> questKeys,
  }) async {
    replacedJourneyId = journeyId;
    return snapshot.journeys.firstWhere((journey) => journey.id == journeyId);
  }

  @override
  Future<DomainJourney> updateJourney({
    required String journeyId,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    updatedJourneyId = journeyId;
    final current = snapshot.journeys.singleWhere(
      (journey) => journey.id == journeyId,
    );
    final updated = DomainJourney(
      id: current.id,
      regionKey: current.regionKey,
      questKeys: current.questKeys,
      title: title,
      startDate: startDate,
      endDate: endDate,
      status: current.status,
      createdAt: current.createdAt,
    );
    snapshot = DomainSnapshot(
      catalog: snapshot.catalog,
      journeys: [updated],
      completedQuestKeys: snapshot.completedQuestKeys,
      regionProgress: snapshot.regionProgress,
      regionTripCount: snapshot.regionTripCount,
      timeline: snapshot.timeline,
    );
    return updated;
  }

  @override
  Future<void> deleteJourney({required String journeyId}) async {
    deletedJourneyId = journeyId;
    snapshot = DomainSnapshot(
      catalog: snapshot.catalog,
      journeys: const [],
      completedQuestKeys: const {},
      regionProgress: const {},
      regionTripCount: const {},
      timeline: const [],
    );
  }

  @override
  Future<String> uploadPhoto(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
  }) async => '/uploads/photos/x.jpg';

  @override
  Future<QuestVerification> verifyQuest({
    required String questKey,
    String? journeyId,
    String? photoUrl,
    String? answer,
    String? qrPayload,
  }) async => const QuestVerification(verified: true);
}

void main() {
  test(
    'server snapshot hydrates legacy screen state after bootstrap',
    () async {
      final repository = _Repository();
      final container = ProviderContainer(
        overrides: [domainRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container.read(domainControllerProvider.future);

      final progress = container.read(progressProvider);
      expect(progress.completedQuestIds, {'dy1'});
      expect(progress.tripQuestsOf('danyang'), {'dy1'});
      expect(progress.tripInfoOf('danyang')?.name, '단양 여행');
      expect(progress.regionProgress, {'danyang': 1});
      expect(progress.timeline.single.photoUrl, '/uploads/photos/x.jpg');
    },
  );

  test('failed journey creation does not report local success', () async {
    final repository = _Repository()..createError = Exception('offline');
    final container = ProviderContainer(
      overrides: [domainRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(domainControllerProvider.future);
    final before = container.read(progressProvider);

    await expectLater(
      container
          .read(domainControllerProvider.notifier)
          .createJourney(
            regionKey: 'danyang',
            questKeys: const ['dy1'],
            title: '단양 여행',
            startDate: DateTime(2026, 7, 20),
            endDate: DateTime(2026, 7, 22),
          ),
      throwsA(isA<Exception>()),
    );

    expect(container.read(progressProvider), same(before));
    expect(repository.createCalls, 1);
    expect(repository.fetchCalls, 1);
  });

  test('journey retry reuses the same client idempotency key', () async {
    final repository = _Repository()..createError = Exception('response lost');
    final container = ProviderContainer(
      overrides: [domainRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(domainControllerProvider.future);
    final controller = container.read(domainControllerProvider.notifier);

    Future<void> create() => controller.createJourney(
      regionKey: 'danyang',
      questKeys: const ['dy1'],
      title: '단양 여행',
      startDate: DateTime(2026, 7, 20),
      endDate: DateTime(2026, 7, 22),
    );
    await expectLater(create(), throwsA(isA<Exception>()));
    repository.createError = null;
    await create();

    expect(repository.createRequestIds, hasLength(2));
    expect(repository.createRequestIds.toSet(), hasLength(1));
  });

  test('quest replacement targets the explicitly selected journey', () async {
    final repository = _Repository();
    repository.snapshot = DomainSnapshot(
      catalog: _catalog,
      journeys: [
        ...repository.snapshot.journeys,
        DomainJourney(
          id: 'older-journey',
          regionKey: 'danyang',
          questKeys: const ['dy1'],
          title: '이전 단양 여행',
          startDate: DateTime(2026, 6, 1),
          endDate: DateTime(2026, 6, 2),
          status: 'completed',
          createdAt: DateTime(2026, 6, 1),
        ),
      ],
      completedQuestKeys: repository.snapshot.completedQuestKeys,
      regionProgress: repository.snapshot.regionProgress,
      regionTripCount: repository.snapshot.regionTripCount,
      timeline: repository.snapshot.timeline,
    );
    final container = ProviderContainer(
      overrides: [domainRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(domainControllerProvider.future);

    await container
        .read(domainControllerProvider.notifier)
        .replaceJourneyQuests(
          journeyId: 'older-journey',
          questKeys: const ['dy1'],
        );

    expect(repository.replacedJourneyId, 'older-journey');
  });

  test('journey update refreshes snapshot projection', () async {
    final repository = _Repository();
    final container = ProviderContainer(
      overrides: [domainRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(domainControllerProvider.future);

    await container
        .read(domainControllerProvider.notifier)
        .updateJourney(
          journeyId: 'journey-uuid',
          title: '수정 여행',
          startDate: DateTime(2026, 8),
          endDate: DateTime(2026, 8, 2),
        );

    expect(repository.updatedJourneyId, 'journey-uuid');
    final journey = container
        .read(domainControllerProvider)
        .value!
        .journeys
        .single;
    expect(journey.title, '수정 여행');
    expect(
      container.read(progressProvider).tripInfoOf('danyang')?.name,
      '수정 여행',
    );
  });

  test(
    'journey deletion clears local coloring override and refreshes',
    () async {
      final repository = _Repository()..snapshot = _snapshot(completed: false);
      final container = ProviderContainer(
        overrides: [domainRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(domainControllerProvider.future);
      final quest = kQuests.firstWhere((quest) => quest.region == 'danyang');
      container.read(progressProvider.notifier).startTrip(
        'danyang',
        {quest.id},
        TripInfo(
          name: '단양 여행',
          startDate: DateTime(2026, 7, 20),
          endDate: DateTime(2026, 7, 22),
        ),
      );
      container.read(progressProvider.notifier).completeQuest(quest.id);
      final otherQuest = kQuests.firstWhere(
        (quest) => quest.region != 'danyang',
      );
      container.read(progressProvider.notifier).startTrip(
        otherQuest.region,
        {otherQuest.id},
        TripInfo(
          name: '다른 여행',
          startDate: DateTime(2026, 7, 20),
          endDate: DateTime(2026, 7, 22),
        ),
      );
      container.read(progressProvider.notifier).completeQuest(otherQuest.id);
      expect(container.read(progressProvider).localTripCompletions, {
        'danyang': 1,
        otherQuest.region: 1,
      });

      await container
          .read(domainControllerProvider.notifier)
          .deleteJourney(journeyId: 'journey-uuid');

      expect(repository.deletedJourneyId, 'journey-uuid');
      expect(container.read(domainControllerProvider).value!.journeys, isEmpty);
      expect(container.read(progressProvider).localTripCompletions, {
        otherQuest.region: 1,
      });
    },
  );

  test(
    'keeps a persisted verification successful when snapshot refresh fails',
    () async {
      final repository = _Repository();
      final container = ProviderContainer(
        overrides: [domainRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(domainControllerProvider.future);
      repository.fetchError = Exception('offline');

      final result = await container
          .read(domainControllerProvider.notifier)
          .verifyQuest(questKey: 'dy1');

      expect(result.verified, isTrue);
    },
  );
}
