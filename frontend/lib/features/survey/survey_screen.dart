import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_toast.dart';
import '../../data/models/survey_question.dart';
import '../../state/progress_notifier.dart';
import '../../state/repository_providers.dart';

/// 초기 설문(4문항) — 최다 선택 유형을 여행 DNA로 집계한다(프로토타입 surveyNext 로직).
class SurveyScreen extends ConsumerStatefulWidget {
  const SurveyScreen({super.key});

  @override
  ConsumerState<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends ConsumerState<SurveyScreen> {
  int _step = 0;
  late List<String?> _picks;

  @override
  void initState() {
    super.initState();
    final count = ref.read(surveyRepositoryProvider).questions().length;
    _picks = List<String?>.filled(count, null);
  }

  @override
  Widget build(BuildContext context) {
    final questions = ref.watch(surveyRepositoryProvider).questions();
    final SurveyQuestion question = questions[_step];
    final isLast = _step >= questions.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text('설문 ${_step + 1}/${questions.length}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () {
            if (_step == 0) {
              context.go('/signup');
            } else {
              setState(() => _step -= 1);
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              question.question,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            for (final option in question.options)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OptionTile(
                  label: option.label,
                  selected: _picks[_step] == option.dnaType,
                  onTap: () => setState(() => _picks[_step] = option.dnaType),
                ),
              ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => _next(isLast),
              child: Text(isLast ? '결과 보기' : '다음'),
            ),
          ],
        ),
      ),
    );
  }

  void _next(bool isLast) {
    if (_picks[_step] == null) {
      showAppToast(context, '선택지를 골라주세요');
      return;
    }
    if (!isLast) {
      setState(() => _step += 1);
      return;
    }
    final tally = <String, int>{};
    for (final pick in _picks) {
      if (pick != null) tally[pick] = (tally[pick] ?? 0) + 1;
    }
    var best = 'nature';
    var max = -1;
    tally.forEach((type, count) {
      if (count > max) {
        max = count;
        best = type;
      }
    });
    ref.read(progressProvider.notifier).setDnaType(best);
    context.go('/dna-result');
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF1F7EC) : Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? AppColors.primaryDark : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
