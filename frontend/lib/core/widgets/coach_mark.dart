import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/onboarding_tour_notifier.dart';
import '../constants.dart';

/// 실제 화면의 특정 위젯([targetKey])을 스포트라이트로 강조하고 화살표+말풍선으로 설명하는
/// 온보딩 코치마크. 각 화면에서 `OnboardingTourState.step == stepIndex`일 때만 띄운다.
class CoachMarkOverlay extends ConsumerStatefulWidget {
  const CoachMarkOverlay({
    super.key,
    required this.targetKey,
    required this.stepIndex,
    required this.title,
    required this.body,
    this.scrollAlignment = 0.5,
  });

  final GlobalKey targetKey;
  final int stepIndex;
  final String title;
  final String body;

  /// [Scrollable.ensureVisible]에 넘기는 정렬 값. 기본은 화면 중앙(0.5)이지만,
  /// 타겟이 화면의 상당 부분을 차지해 중앙 정렬 시 말풍선 놓을 위·아래 공간이
  /// 모자라면(예: 홈 지도) 0.0(뷰포트 상단)으로 넘겨 아래쪽에 공간을 확보한다.
  final double scrollAlignment;

  @override
  ConsumerState<CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends ConsumerState<CoachMarkOverlay> {
  Rect? _targetRect;
  Size? _localSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  Future<void> _measure() async {
    final ctx = widget.targetKey.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 200),
      alignment: widget.scrollAlignment,
    );
    if (!mounted || !ctx.mounted) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    // Positioned은 이 위젯을 감싼 Stack 기준 좌표계를 쓰므로, 전역(root) 좌표가 아니라
    // 그 Stack을 기준(ancestor)으로 변환해야 위치가 맞는다(AppBar 높이만큼 어긋나는 문제 방지).
    final stackBox = context.findRenderObject()?.parent as RenderBox?;
    final topLeft = stackBox != null
        ? box.localToGlobal(Offset.zero, ancestor: stackBox)
        : box.localToGlobal(Offset.zero);
    setState(() {
      _targetRect = topLeft & box.size;
      _localSize = stackBox?.size;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rect = _targetRect;
    if (rect == null) return const SizedBox.shrink();

    final isLastStep = widget.stepIndex >= kOnboardingTotalSteps - 1;
    final screenSize = _localSize ?? MediaQuery.sizeOf(context);
    const bubbleAllowance = 260.0;
    const margin = 16.0;

    final spaceBelow = screenSize.height - rect.bottom;
    final spaceAbove = rect.top;
    // 타겟(예: 지도)이 화면보다 커서 위·아래 어디에도 말풍선 놓을 공간이 부족하면
    // 화면 중앙에 띄운다 — 화살표로 특정 방향을 가리키는 대신 스포트라이트만으로 강조.
    final _BubblePlacement placement;
    if (spaceBelow >= bubbleAllowance) {
      placement = _BubblePlacement.below;
    } else if (spaceAbove >= bubbleAllowance) {
      placement = _BubblePlacement.above;
    } else {
      placement = _BubblePlacement.center;
    }

    final bubble = _MessageCard(
      stepIndex: widget.stepIndex,
      title: widget.title,
      body: widget.body,
      isLastStep: isLastStep,
    );

    return Positioned.fill(
      child: Stack(
        children: [
          // AbsorbPointer로 스크림이 터치를 흡수해 뒤 화면의 탭·스크롤이 전달되지 않게 막는다
          // (코치마크가 떠 있는 동안 실제 화면을 조작할 수 없어야 한다).
          Positioned.fill(
            child: AbsorbPointer(
              child: CustomPaint(painter: _SpotlightPainter(rect.inflate(8))),
            ),
          ),
          switch (placement) {
            _BubblePlacement.below => Positioned(
              left: margin,
              right: margin,
              top: rect.bottom + margin,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.arrow_upward, color: Colors.white, size: 26),
                  bubble,
                ],
              ),
            ),
            _BubblePlacement.above => Positioned(
              left: margin,
              right: margin,
              bottom: screenSize.height - rect.top + margin,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  bubble,
                  const Icon(
                    Icons.arrow_downward,
                    color: Colors.white,
                    size: 26,
                  ),
                ],
              ),
            ),
            _BubblePlacement.center => Positioned(
              left: margin,
              right: margin,
              top: margin,
              bottom: margin,
              child: Center(child: bubble),
            ),
          },
        ],
      ),
    );
  }
}

enum _BubblePlacement { below, above, center }

class _MessageCard extends ConsumerWidget {
  const _MessageCard({
    required this.stepIndex,
    required this.title,
    required this.body,
    required this.isLastStep,
  });

  final int stepIndex;
  final String title;
  final String body;
  final bool isLastStep;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${stepIndex + 1}/$kOnboardingTotalSteps',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () =>
                    ref.read(onboardingTourProvider.notifier).skipForever(),
                style: TextButton.styleFrom(minimumSize: const Size(48, 40)),
                child: const Text(
                  '다시 보지 않기',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
              ElevatedButton(
                onPressed: () =>
                    ref.read(onboardingTourProvider.notifier).advance(),
                // 앱 전역 테마가 ElevatedButton에 Size.fromHeight(56)(가로 무한대)를 강제해
                // 전체 폭 버튼을 기본값으로 삼는데, 이 버튼은 Row 안에서 옆 버튼과 나란히 쓰이므로
                // 여기서만 좁은 minimumSize로 오버라이드한다.
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(64, 40),
                ),
                child: Text(isLastStep ? '확인했어요' : '다음'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter(this.holeRect);

  final Rect holeRect;

  @override
  void paint(Canvas canvas, Size size) {
    final fullScreen = Path()..addRect(Offset.zero & size);
    final hole = Path()
      ..addRRect(RRect.fromRectAndRadius(holeRect, const Radius.circular(12)));
    final scrim = Path.combine(PathOperation.difference, fullScreen, hole);
    canvas.drawPath(
      scrim,
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(holeRect, const Radius.circular(12)),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.holeRect != holeRect;
}
