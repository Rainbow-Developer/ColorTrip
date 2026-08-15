import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/step_progress.dart';
import '../../data/models/category_vocabulary.dart';
import '../../data/models/trip_dna_question.dart';
import '../../state/progress_notifier.dart';
import '../../state/auth_controller.dart';
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _exitSurvey();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('여행 DNA 설문'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: _exitSurvey,
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '설문 질문지를 불러오지 못했습니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.redAccent, fontSize: 15),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _retryQuestions,
                        child: const Text('다시 시도'),
                      ),
                    ],
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
                  // 문항 수만큼 칸을 만들어 지금 몇 번째인지 보여준다(KAN-75).
                  // 문항 수는 서버 응답에 달려 있어 하드코딩하지 않는다.
                  Text(
                    '${_step + 1} / ${questions.length}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  StepProgress(
                    totalSteps: questions.length,
                    currentStep: _step + 1,
                  ),
                  const SizedBox(height: 24),
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
                  Row(
                    children: [
                      if (_step > 0) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _submitting ? null : _previousQuestion,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(17),
                              ),
                              side: const BorderSide(
                                color: Color(0xFFB2C2AD),
                                width: 1.5,
                              ),
                              foregroundColor: Colors.black87,
                              textStyle: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: const Text('이전'),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton(
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
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _retryQuestions() {
    setState(() {
      _step = 0;
      _picks = null;
      _questionsFuture = ref.read(tripDnaRepositoryProvider).questions();
    });
  }

  void _previousQuestion() {
    if (_step > 0) {
      setState(() => _step -= 1);
    }
  }

  Future<void> _exitSurvey() async {
    if (context.canPop()) {
      context.pop();
      return;
    }

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('여행 DNA 진단을 중단할까요?'),
        content: const Text('진단을 중단하면 로그아웃되며 다음 로그인 때 다시 진행할 수 있습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('계속 진행'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (shouldLogout != true || !mounted) return;
    await ref.read(authControllerProvider.notifier).logout();
    if (!mounted) return;
    ref.read(progressProvider.notifier).reset();
    context.go('/splash');
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
      // 서버의 `activity` 분류를 기존 앱 화면이 사용하는 `active` 분류로
      // 일관되게 변환한다.
      final mainDnaType = toAppCategory(result['main_dna_type'] as String);

      ref.read(progressProvider.notifier).setDnaType(mainDnaType);
      final refreshed = await ref
          .read(authControllerProvider.notifier)
          .refreshCurrentUser();
      if (!refreshed) {
        if (mounted) {
          showAppToast(context, '결과를 확인하지 못했습니다. 다시 시도해주세요.');
        }
        return;
      }

      if (mounted) {
        context.go('/trip-dna/result');
      }
    } on Object {
      if (mounted) {
        showAppToast(context, '답변 제출에 실패했습니다. 다시 시도해주세요.');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

class _OptionTile extends StatefulWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile> {
  var _showFocus = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: widget.label,
      selected: widget.selected,
      button: true,
      excludeSemantics: true,
      child: FocusableActionDetector(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        onShowFocusHighlight: (value) => setState(() => _showFocus = value),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: widget.selected ? const Color(0xFFF1F7EC) : Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: widget.selected || _showFocus
                    ? AppColors.primaryDark
                    : AppColors.border,
                width: _showFocus ? 2 : 1.5,
              ),
            ),
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
