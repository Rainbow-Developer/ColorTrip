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
    // 이 위젯 자신의 findRenderObject()가 아니라 부모(실제 Stack)를 써야 한다 — 측정 전
    // build()는 SizedBox.shrink()(크기 0)를 반환하므로, 자기 자신을 기준 삼으면 항상
    // 크기가 0으로 잡혀 스포트라이트가 그려지지 않는다.
    final overlayBox = context.findRenderObject()?.parent as RenderBox?;
    if (box == null || overlayBox == null) return;
    // Positioned은 이 위젯을 감싼 Stack 기준 좌표계를 쓰므로, 전역(root) 좌표가 아니라
    // 그 Stack 기준 좌표로 변환해야 위치가 맞는다(AppBar 높이만큼 어긋나는 문제 방지).
    // localToGlobal(ancestor:)는 실제 조상 관계를 요구해 assert로 죽으므로, 각자 전역
    // 좌표를 구한 뒤 빼는 방식으로 계산한다. 단, targetKey는 반드시 이 CoachMarkOverlay와
    // 같은 Stack 안에 있어야 한다 — Scaffold.bottomNavigationBar처럼 body Stack 밖에
    // 있으면 좌표는 계산되어도 스포트라이트가 body 영역 밖이라 그려지지 않는다.
    final topLeft =
        box.localToGlobal(Offset.zero) - overlayBox.localToGlobal(Offset.zero);
    setState(() {
      _targetRect = topLeft & box.size;
      _localSize = overlayBox.size;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rect = _targetRect;
    if (rect == null) return const SizedBox.shrink();

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
    );

    final hole = rect.inflate(8);

    return Positioned.fill(
      child: Stack(
        children: [
          // CustomPaint는 히트테스트를 흡수하지 않으므로(시각 효과만 담당) 순수하게 그리기용
          // — 화면 어디를 눌러도 실제 화면이 그대로 반응한다. 예를 들어 "여행 시작하기"
          // 코치마크 단계에서는 그 버튼뿐 아니라 위쪽 퀘스트 목록(전제 조건)도 눌러야 하므로,
          // hole 밖을 흡수해 막으면 오히려 투어를 진행할 수 없게 된다. 실제 타겟을 조작하는
          // 것 자체가 다음 단계로의 진행 트리거다(각 화면의 onTap/onPressed에서 advance() 호출).
          IgnorePointer(child: CustomPaint(painter: _SpotlightPainter(hole))),
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
  });

  final int stepIndex;
  final String title;
  final String body;

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
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () =>
                  ref.read(onboardingTourProvider.notifier).skipForever(),
              style: TextButton.styleFrom(minimumSize: const Size(48, 40)),
              child: const Text(
                '다시 보지 않기',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
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
