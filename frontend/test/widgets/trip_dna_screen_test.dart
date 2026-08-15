import 'dart:ui';

import 'package:colortrip/core/widgets/step_progress.dart';
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

const _fourQuestions = [
  TripDnaQuestion(
    id: 'question-1',
    question: '여행 계획을 세울 때 가장 먼저 찾아보는 것은?',
    options: [
      TripDnaOption(id: 'option-1', label: '자연 경관'),
      TripDnaOption(id: 'option-2', label: '맛집'),
    ],
  ),
  TripDnaQuestion(
    id: 'question-2',
    question: '아침에 일어나 하고 싶은 일은?',
    options: [
      TripDnaOption(id: 'option-3', label: '산책'),
      TripDnaOption(id: 'option-4', label: '카페'),
    ],
  ),
  TripDnaQuestion(
    id: 'question-3',
    question: '완벽한 하루의 마무리는?',
    options: [
      TripDnaOption(id: 'option-5', label: '노을'),
      TripDnaOption(id: 'option-6', label: '야시장'),
    ],
  ),
  TripDnaQuestion(
    id: 'question-4',
    question: '친구가 부르는 별명은?',
    options: [
      TripDnaOption(id: 'option-7', label: '탐험가'),
      TripDnaOption(id: 'option-8', label: '미식가'),
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

    await tester.binding.handlePopRoute();
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

  testWidgets('shows how far along the survey is across its questions', (
    tester,
  ) async {
    // 회원가입에서 걷어낸 단계 진행바를 여기로 옮겼다 — 문항 수만큼 칸을 만들고
    // 답할 때마다 채운다(KAN-75).
    await tester.pumpWidget(_app(_TripRepository([_fourQuestions])));
    await tester.pumpAndSettle();

    expect(find.text('1 / 4'), findsOneWidget);
    expect(find.byType(StepProgress), findsOneWidget);
    expect(
      tester.widget<StepProgress>(find.byType(StepProgress)).totalSteps,
      4,
    );
    expect(
      tester.widget<StepProgress>(find.byType(StepProgress)).currentStep,
      1,
    );

    await tester.tap(find.text('자연 경관'));
    await tester.pump();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    expect(find.text('2 / 4'), findsOneWidget);
    expect(
      tester.widget<StepProgress>(find.byType(StepProgress)).currentStep,
      2,
    );
  });
  testWidgets('appbar back button pops route when retaking survey regardless of step', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [tripDnaRepositoryProvider.overrideWithValue(_TripRepository([_fourQuestions]))],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TripDnaScreen()),
              ),
              child: const Text('Push'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Push'));
    await tester.pumpAndSettle();

    // 1번 문항에서 2번 문항으로 이동
    await tester.tap(find.text('자연 경관'));
    await tester.pump();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    expect(find.text('2 / 4'), findsOneWidget);

    // 좌상단 뒤로가기 버튼(<) 터치
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    // 다시하기 모드(canPop == true)이므로, 이전 문항으로 가는 것이 아니라 화면 자체가 pop 되어야 함
    expect(find.text('Push'), findsOneWidget);
    expect(find.text('2 / 4'), findsNothing);
  });
}
