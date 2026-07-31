import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_toast.dart';
import '../../data/models/category_vocabulary.dart';
import '../../data/models/trip_dna_question.dart';
import '../../state/progress_notifier.dart';
import '../../state/repository_providers.dart';

/// 초기 설문(동적 문항) — 백엔드 API로부터 불러와 답변을 제출하고 DNA 결과를 받아옵니다.
class TripDnaScreen extends ConsumerStatefulWidget {
  const TripDnaScreen({super.key});

  @override
  ConsumerState<TripDnaScreen> createState() => _TripDnaScreenState();
}

class _TripDnaScreenState extends ConsumerState<TripDnaScreen> {
  int _step = 0;
  late Future<List<TripDnaQuestion>> _questionsFuture;
  List<String?>? _picks; // 질문 개수가 확정되면 초기화됩니다.
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _questionsFuture = ref.read(tripDnaRepositoryProvider).questions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('여행 DNA 설문'),
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
      body: FutureBuilder<List<TripDnaQuestion>>(
        future: _questionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  '설문 질문지를 불러오지 못했습니다.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 15),
                ),
              ),
            );
          }
          final questions = snapshot.data;
          if (questions == null || questions.isEmpty) {
            return const Center(child: Text('진행 가능한 설문 질문지가 없습니다.'));
          }

          // 질문 개수가 확인된 후 _picks 리스트 최초 1회 초기화
          _picks ??= List<String?>.filled(questions.length, null);

          final question = questions[_step];
          final isLast = _step >= questions.length - 1;

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Q${_step + 1}. ${question.question}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final option in question.options)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _OptionTile(
                              label: option.label,
                              selected: _picks![_step] == option.id,
                              onTap: () =>
                                  setState(() => _picks![_step] = option.id),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _submitting
                      ? null
                      : () => _next(isLast, questions),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(isLast ? '결과 보기' : '다음'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _next(bool isLast, List<TripDnaQuestion> questions) async {
    if (_picks == null || _picks![_step] == null) {
      showAppToast(context, '선택지를 골라주세요');
      return;
    }
    if (!isLast) {
      setState(() => _step += 1);
      return;
    }

    // payload: [{"question_id": "...", "question_option_id": "..."}, ...]
    final replies = <Map<String, String>>[];
    for (var i = 0; i < questions.length; i++) {
      replies.add({
        'question_id': questions[i].id,
        'question_option_id': _picks![i]!,
      });
    }

    setState(() => _submitting = true);
    try {
      final result = await ref
          .read(tripDnaRepositoryProvider)
          .submitReplies(replies);
      // 서버 어휘(activity) → 앱 어휘(active). 변환하지 않으면 액티비티 판정 사용자의
      // DNA 조회가 실패해 자연 탐험으로 조용히 대체된다([category_vocabulary.dart]).
      final String mainDnaType = toAppCategory(
        result['main_dna_type'] as String,
      );

      ref.read(progressProvider.notifier).setDnaType(mainDnaType);

      if (mounted) {
        context.go('/trip-dna/result');
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, '답변 제출에 실패했습니다: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
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
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
