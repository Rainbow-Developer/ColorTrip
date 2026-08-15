import 'dart:async';

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
  final _overlayKey = GlobalKey();
  Rect? _targetRect;
  Size? _localSize;
  bool _measureScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant CoachMarkOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 추천 퀘스트처럼 비동기 데이터가 도착하면 부모 레이아웃 높이와 하단 CTA 위치가
    // 달라질 수 있다. 부모가 다시 빌드될 때 실제 타겟 위치를 다음 프레임에서 갱신한다.
    _scheduleMeasure();
  }

  void _scheduleMeasure() {
    if (_measureScheduled) return;
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (mounted) unawaited(_measure());
    });
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
    final overlayBox =
        _overlayKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null) return;
    // 타겟과 오버레이의 전역 좌표 차이를 사용해 오버레이 내부 좌표로 변환한다.
    // StatefulElement에서 임의의 첫 RenderObject를 찾으면 빌드 결과에 따라 기준점이
    // 달라질 수 있으므로, 화면 전체를 차지하는 [_overlayKey]를 고정 기준으로 사용한다.
    final topLeft =
        box.localToGlobal(Offset.zero) - overlayBox.localToGlobal(Offset.zero);
    final nextRect = topLeft & box.size;
    if (_targetRect == nextRect && _localSize == overlayBox.size) return;
    setState(() {
      _targetRect = nextRect;
      _localSize = overlayBox.size;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rect = _targetRect;
    if (rect == null) {
      return Positioned.fill(child: SizedBox.expand(key: _overlayKey));
    }

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
      child: SizedBox.expand(
        key: _overlayKey,
        child: Stack(
          children: [
            // Stack의 일반 자식인 CustomPaint는 기본 크기가 0이다. Positioned.fill로
            // 오버레이 전체 크기를 강제해야 반투명 딤이 실제 화면 전체에 그려진다.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  key: const ValueKey('coach-mark-scrim'),
                  painter: _SpotlightPainter(hole),
                ),
              ),
            ),
            Positioned.fill(
              child: _SpotlightHitTestBlocker(passthroughRect: hole),
            ),
            switch (placement) {
              _BubblePlacement.below => Positioned(
                left: margin,
                right: margin,
                top: rect.bottom + margin,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.arrow_upward,
                      color: Colors.white,
                      size: 26,
                    ),
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
      ),
    );
  }
}

enum _BubblePlacement { below, above, center }

class _SpotlightHitTestBlocker extends LeafRenderObjectWidget {
  const _SpotlightHitTestBlocker({required this.passthroughRect});

  final Rect passthroughRect;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSpotlightHitTestBlocker(passthroughRect);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderSpotlightHitTestBlocker renderObject,
  ) {
    renderObject.passthroughRect = passthroughRect;
  }
}

class _RenderSpotlightHitTestBlocker extends RenderBox {
  _RenderSpotlightHitTestBlocker(this._passthroughRect);

  Rect _passthroughRect;

  set passthroughRect(Rect value) {
    if (_passthroughRect == value) return;
    _passthroughRect = value;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  bool hitTestSelf(Offset position) => !_passthroughRect.contains(position);
}

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
