import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_toast.dart';
import '../../data/models/quest.dart';
import '../../state/progress_notifier.dart';
import '../../state/repository_providers.dart';

/// 퀘스트 수행(인증) 화면 — 여행 시작하기로 담은 퀘스트를 지역 개요("여행하기")의
/// "내 여행 퀘스트" 목록에서 탭하면 여기로 온다(2026-07-09 사용자 확정 — 퀘스트 상세에는
/// 더 이상 수행 버튼이 없다). 사진/GPS/OX퀴즈 유형별 UI는 Figma 스펙(2026-07-08 공유) 반영.
/// 실제 카메라/GPS 연동은 없고, 선택·인증 상호작용만 흉내 낸 최소 버전이다
/// ([implementation.md] 참고 — 스캔 애니메이션·실연동은 후속 작업).
class QuestVerifyScreen extends ConsumerWidget {
  const QuestVerifyScreen({super.key, required this.questId});

  final String questId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quest = ref.watch(questRepositoryProvider).byId(questId);
    if (quest == null) {
      return const Scaffold(body: Center(child: Text('퀘스트를 찾을 수 없어요')));
    }

    void completeAndPop() {
      ref
          .read(progressProvider.notifier)
          .completeQuest(questId, month: DateTime.now().month);
      showAppToast(context, '퀘스트 완료! 지도가 칠해졌어요');
      context.pop();
      context.pop();
    }

    void completeAndShowResult() {
      ref
          .read(progressProvider.notifier)
          .completeQuest(questId, month: DateTime.now().month);
      context.push('/quest/$questId/verify/result');
    }

    switch (quest.verify) {
      case 'gps':
        return _GpsVerifyBody(
          questTitle: quest.title,
          onVerified: completeAndPop,
        );
      case 'quiz':
        return _QuizVerifyBody(quest: quest, onVerified: completeAndPop);
      default:
        return _PhotoVerifyBody(
          questTitle: quest.title,
          onVerified: completeAndShowResult,
        );
    }
  }
}

class _QuizVerifyBody extends StatefulWidget {
  const _QuizVerifyBody({required this.quest, required this.onVerified});

  final Quest quest;
  final VoidCallback onVerified;

  @override
  State<_QuizVerifyBody> createState() => _QuizVerifyBodyState();
}

class _QuizVerifyBodyState extends State<_QuizVerifyBody> {
  bool? _wrong;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('OX 퀴즈'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.quest.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                widget.quest.quizQuestion ?? '',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (_wrong == true) ...[
              const SizedBox(height: 8),
              const Text(
                '다시 생각해보세요.',
                style: TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _answer(true),
                    child: const Text('O'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _answer(false),
                    child: const Text('X'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _answer(bool value) {
    if (value == widget.quest.quizAnswer) {
      widget.onVerified();
    } else {
      setState(() => _wrong = true);
    }
  }
}

class _GpsVerifyBody extends StatelessWidget {
  const _GpsVerifyBody({required this.questTitle, required this.onVerified});

  final String questTitle;
  final VoidCallback onVerified;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('GPS 인증'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              questTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              '반경 500m 이내여야 합니다.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.verifyMapBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryDark,
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Text('📍'),
                    ),
                  ),
                  const Positioned(
                    left: 12,
                    top: 10,
                    child: Text(
                      '지도 미리보기',
                      style: TextStyle(color: AppColors.formPlaceholder),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.timelineLine),
                      ),
                      child: const Text(
                        '현재 위치',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '현재 위치',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      const Text(
                        '위치 확인 중...',
                        style: TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '목적지까지 약 120m',
                    style: TextStyle(
                      color: AppColors.timelineDateText,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: 0.69,
                      minHeight: 4,
                      backgroundColor: AppColors.verifyProgressTrack,
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'ℹ️ GPS 정확도에 따라 인증이 지연될 수 있습니다. 실외에서 시도해주세요.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: onVerified,
              child: const Text('현재 위치로 인증하기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoVerifyBody extends StatefulWidget {
  const _PhotoVerifyBody({required this.questTitle, required this.onVerified});

  final String questTitle;
  final VoidCallback onVerified;

  @override
  State<_PhotoVerifyBody> createState() => _PhotoVerifyBodyState();
}

class _PhotoVerifyBodyState extends State<_PhotoVerifyBody> {
  bool _photoSelected = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('사진 인증'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.questTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              '퀘스트 장소 사진을 업로드해주세요.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () => setState(() => _photoSelected = true),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.uploadBoxBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _photoSelected
                        ? AppColors.primaryDark
                        : AppColors.uploadBoxBorder,
                  ),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _photoSelected ? '✅' : '📷',
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _photoSelected ? '사진이 선택됐어요' : '사진 촬영 또는 갤러리 선택',
                      style: const TextStyle(
                        color: AppColors.formPlaceholder,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PhotoSourceButton(
                    label: '📷 카메라',
                    onTap: () => setState(() => _photoSelected = true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PhotoSourceButton(
                    label: '🖼 갤러리',
                    onTap: () => setState(() => _photoSelected = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '업로드 가이드',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '• 퀘스트 장소가 잘 보이는 사진\n• 최근 24시간 이내 촬영\n• 5MB 이하 JPG/PNG',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _photoSelected ? widget.onVerified : null,
              child: Text(_photoSelected ? '사진으로 인증하기' : '사진 선택 후 인증 가능'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoSourceButton extends StatelessWidget {
  const _PhotoSourceButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ),
    );
  }
}
