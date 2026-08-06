import 'dart:typed_data';

import 'package:colortrip/data/repositories/domain_repository.dart';
import 'package:colortrip/state/domain_state_gate.dart';
import 'package:colortrip/state/repository_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository implements DomainRepository {
  var calls = 0;

  @override
  Future<DomainSnapshot> fetchSnapshot() async {
    calls++;
    if (calls == 1) throw Exception('offline');
    return const DomainSnapshot(
      catalog: DomainCatalog(
        regionIdsByKey: {},
        regionKeysById: {},
        questIdsByKey: {},
        questKeysById: {},
      ),
      journeys: [],
      completedQuestKeys: {},
      regionProgress: {},
      regionTripCount: {},
      timeline: [],
    );
  }

  @override
  Future<List<DomainRecommendedRegion>>
  fetchUnvisitedRecommendedRegions() async => const [];

  @override
  Future<List<String>> fetchRecommendedQuestKeys({
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
  }) => throw UnimplementedError();

  @override
  Future<DomainJourney> replaceJourneyQuests({
    required String journeyId,
    required List<String> questKeys,
  }) => throw UnimplementedError();

  @override
  Future<String> uploadPhoto(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
  }) => throw UnimplementedError();

  @override
  Future<QuestVerification> verifyQuest({
    required String questKey,
    String? journeyId,
    double? latitude,
    double? longitude,
    String? photoUrl,
    String? answer,
    String? qrPayload,
  }) => throw UnimplementedError();
}

void main() {
  testWidgets(
    'shows retry instead of disguising domain load failure as empty',
    (tester) async {
      final repository = _Repository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [domainRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(
            home: DomainStateGate(child: Text('여행 콘텐츠')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('여행 정보를 불러오지 못했어요'), findsOneWidget);
      expect(find.text('여행 콘텐츠'), findsNothing);

      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();

      expect(find.text('여행 콘텐츠'), findsOneWidget);
      expect(repository.calls, 2);
    },
  );
}
