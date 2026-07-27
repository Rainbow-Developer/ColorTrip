import 'dart:ui';

import 'package:colortrip/data/models/trip_dna_question.dart';
import 'package:colortrip/data/repositories/trip_dna_repository.dart';
import 'package:colortrip/features/trip_dna/trip_dna_screen.dart';
import 'package:colortrip/state/repository_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _questions = [
  TripDnaQuestion(
    id: 'question-1',
    question: '어떤 여행을 좋아하나요?',
    options: [
      TripDnaOption(id: 'option-1', label: '숲길을 걸어요'),
      TripDnaOption(id: 'option-2', label: '맛집을 찾아요'),
    ],
  ),
];

class _TripRepository implements TripDnaRepository {
  _TripRepository(this.results);

  final List<Object> results;
  int questionsCalls = 0;

  @override
  Future<List<TripDnaQuestion>> questions() async {
    final result = results[questionsCalls++];
    if (result is List<TripDnaQuestion>) return result;
    throw result;
  }

  @override
  Future<Map<String, dynamic>> submitReplies(
    List<Map<String, String>> replies,
  ) async => {'main_dna_type': 'nature'};
}

Widget _app(_TripRepository repository) => ProviderScope(
  overrides: [tripDnaRepositoryProvider.overrideWithValue(repository)],
  child: const MaterialApp(home: TripDnaScreen()),
);

void main() {
  testWidgets(
    'question load failure offers a retry without exposing internals',
    (tester) async {
      final repository = _TripRepository([
        StateError('secret server details'),
        _questions,
      ]);
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      expect(find.text('설문 질문지를 불러오지 못했습니다.'), findsOneWidget);
      expect(find.textContaining('secret server details'), findsNothing);
      expect(find.text('다시 시도'), findsOneWidget);

      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();

      expect(find.textContaining('어떤 여행을 좋아하나요?'), findsOneWidget);
      expect(repository.questionsCalls, 2);
    },
  );

  testWidgets('first-step back asks before ending onboarding', (tester) async {
    await tester.pumpWidget(_app(_TripRepository([_questions])));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    expect(find.text('여행 DNA 진단을 중단할까요?'), findsOneWidget);
    expect(find.text('계속 진행'), findsOneWidget);
    expect(find.text('로그아웃'), findsOneWidget);
  });

  testWidgets('DNA options expose selected semantics', (tester) async {
    await tester.pumpWidget(_app(_TripRepository([_questions])));
    await tester.pumpAndSettle();
    final option = find.bySemanticsLabel('숲길을 걸어요');

    await tester.tap(option);
    await tester.pump();

    expect(
      tester.getSemantics(option).flagsCollection.isSelected,
      Tristate.isTrue,
    );
  });
}
