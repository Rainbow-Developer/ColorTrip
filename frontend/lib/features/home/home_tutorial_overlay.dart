import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../state/home_tutorial_notifier.dart';

class _TutorialSlide {
  const _TutorialSlide({
    required this.emoji,
    required this.title,
    required this.body,
  });

  final String emoji;
  final String title;
  final String body;
}

/// 여행 시작부터 퀘스트 인증까지 전체 흐름을 순서대로 보여주는 슬라이드 —
/// 실제 화면 문구("퀘스트 선택하기", "여행 시작하기")에 맞춰 작성한다.
/// 3번째 슬라이드의 "여행 제목 짓기"는 아직 구현되지 않은 기능(KAN-047 예정)이라
/// 설명만 먼저 넣어두고, 기능이 생기면 실제 화면 캡처/인터랙션으로 교체한다.
const _kTutorialSlides = [
  _TutorialSlide(
    emoji: '🗺️',
    title: '1. 지도에서 지역을 눌러보세요',
    body: '아래 지도에서 가고 싶은 지역을 누르면\n그 지역의 추천 퀘스트를 볼 수 있어요.',
  ),
  _TutorialSlide(
    emoji: '🎯',
    title: '2. 퀘스트를 선택해보세요',
    body: '추천 퀘스트를 확인하고 "퀘스트 선택하기"를 누르면\n이번 여행에서 수행할 퀘스트를 여러 개 고를 수 있어요.',
  ),
  _TutorialSlide(
    emoji: '🚩',
    title: '3. 여행을 시작해보세요',
    body: '퀘스트를 고른 뒤 "여행 시작하기"를 누르면\n나만의 여행이 시작돼요.\n(여행 이름 짓기 기능은 곧 추가될 예정이에요)',
  ),
  _TutorialSlide(
    emoji: '✅',
    title: '4. 퀘스트를 인증해보세요',
    body:
        '여행 탭의 "내 여행 퀘스트"에서 퀘스트를 누르면\n인증 화면으로 이동해요.\n사진·GPS·퀴즈로 인증하면 퀘스트가 완료돼요.',
  ),
];

/// 홈 화면 최초 진입 시 노출되는 안내 가이드 — 여행 시작부터 퀘스트 인증까지의 전체 흐름을
/// 여러 장으로 나눠 순서대로 보여준다(KAN-041/KAN-040 피드백 반영). "다시 보지 않기"로 영구
/// 종료 가능하며, 껐다 켜기는 마이 > 설정에서 다시 할 수 있다.
class HomeTutorialOverlay extends ConsumerStatefulWidget {
  const HomeTutorialOverlay({super.key});

  @override
  ConsumerState<HomeTutorialOverlay> createState() =>
      _HomeTutorialOverlayState();
}

class _HomeTutorialOverlayState extends ConsumerState<HomeTutorialOverlay> {
  final _pageController = PageController();
  bool _dontShowAgain = false;
  int _page = 0;

  bool get _isLastPage => _page == _kTutorialSlides.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _dismiss() => ref
      .read(homeTutorialDismissedProvider.notifier)
      .dismiss(persist: _dontShowAgain);

  void _next() {
    if (_isLastPage) {
      _dismiss();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _dismiss,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 32),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text(
                      '건너뛰기',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 220,
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (page) => setState(() => _page = page),
                    children: [
                      for (final slide in _kTutorialSlides)
                        _SlideContent(slide: slide),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _kTutorialSlides.length; i++)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _page
                              ? AppColors.primaryDark
                              : AppColors.checkboxBorder,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => setState(() => _dontShowAgain = !_dontShowAgain),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _dontShowAgain
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 18,
                        color: _dontShowAgain
                            ? AppColors.primaryDark
                            : AppColors.checkboxBorder,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '다시 보지 않기',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _next,
                  child: Text(_isLastPage ? '확인했어요' : '다음'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SlideContent extends StatelessWidget {
  const _SlideContent({required this.slide});

  final _TutorialSlide slide;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(slide.emoji, style: const TextStyle(fontSize: 32)),
        const SizedBox(height: 12),
        Text(
          slide.title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          slide.body,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
