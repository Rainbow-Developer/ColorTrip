import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../state/home_tutorial_notifier.dart';

/// 홈 화면 최초 진입 시 노출되는 안내 가이드 — 지도에서 지역을 누르면 퀘스트 선택·여행 시작으로
/// 이어진다는 것을 처음 온 사용자에게 알려준다(KAN-041). "다시 보지 않기"로 영구 종료 가능하며,
/// 껐다 켜기는 마이 > 설정에서 다시 할 수 있다.
class HomeTutorialOverlay extends ConsumerStatefulWidget {
  const HomeTutorialOverlay({super.key});

  @override
  ConsumerState<HomeTutorialOverlay> createState() =>
      _HomeTutorialOverlayState();
}

class _HomeTutorialOverlayState extends ConsumerState<HomeTutorialOverlay> {
  bool _dontShowAgain = false;

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
                const Text('🗺️', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 12),
                const Text(
                  '지도에서 지역을 눌러보세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  '아래 지도에서 가고 싶은 지역을 누르면\n퀘스트를 선택하고 여행을 시작할 수 있어요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
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
                  onPressed: () => ref
                      .read(homeTutorialDismissedProvider.notifier)
                      .dismiss(persist: _dontShowAgain),
                  child: const Text('확인했어요'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
