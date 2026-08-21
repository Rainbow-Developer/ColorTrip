import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/onboarding_tour_notifier.dart';
import '../constants.dart';

const _spotlightMargin = 16.0;
const _bubbleArrowSize = 26.0;

double _requiredBubbleSpace(double messageCardHeight) =>
    messageCardHeight + _bubbleArrowSize + _spotlightMargin * 2;

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
    this.forceBubbleBelow = false,
    this.onBackgroundTap,
  });

  final GlobalKey targetKey;
  final int stepIndex;
  final String title;
  final String body;

  /// [Scrollable.ensureVisible]에 넘기는 정렬 값. 기본은 화면 중앙(0.5)이지만,
  /// 타겟이 화면의 상당 부분을 차지해 중앙 정렬 시 말풍선 놓을 위·아래 공간이
  /// 모자라면(예: 홈 지도) 0.0(뷰포트 상단)으로 넘겨 아래쪽에 공간을 확보한다.
  final double scrollAlignment;

  /// true이면 말풍선을 항상 타겟 아래에 둔다. 필요한 경우 타겟을 위쪽으로 더 스크롤해
  /// 말풍선 공간을 만든다.
  final bool forceBubbleBelow;

  /// 하이라이트 바깥의 딤 영역을 탭했을 때 호출한다. 기본은 아무 동작 없이 배경 입력만 막는다.
  final VoidCallback? onBackgroundTap;

  @override
  ConsumerState<CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends ConsumerState<CoachMarkOverlay> {
  final _overlayKey = GlobalKey();
  Rect? _targetRect;
  Size? _localSize;
  ({Size size, TextScaler textScaler, EdgeInsets viewInsets})?
  _lastLayoutDependencies;
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dependencies = (
      size: MediaQuery.sizeOf(context),
      textScaler: MediaQuery.textScalerOf(context),
      viewInsets: MediaQuery.viewInsetsOf(context),
    );
    if (_lastLayoutDependencies == dependencies) return;
    _lastLayoutDependencies = dependencies;
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
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !ctx.mounted) return;

    var measured = _readTargetRect(ctx);
    if (measured == null) return;

    if (widget.forceBubbleBelow) {
      final adjusted = await _makeRoomBelow(
        ctx,
        measured,
        _messageCardHeight(measured.overlaySize),
      );
      if (adjusted != null) measured = adjusted;
    }

    final nextRect = measured.rect;
    final overlaySize = measured.overlaySize;
    if (_targetRect == nextRect && _localSize == overlaySize) return;
    setState(() {
      _targetRect = nextRect;
      _localSize = overlaySize;
    });
  }

  ({Rect rect, Size overlaySize})? _readTargetRect(BuildContext ctx) {
    final box = ctx.findRenderObject() as RenderBox?;
    final overlayBox =
        _overlayKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null) return null;
    // 타겟과 오버레이의 전역 좌표 차이를 사용해 오버레이 내부 좌표로 변환한다.
    // StatefulElement에서 임의의 첫 RenderObject를 찾으면 빌드 결과에 따라 기준점이
    // 달라질 수 있으므로, 화면 전체를 차지하는 [_overlayKey]를 고정 기준으로 사용한다.
    final topLeft =
        box.localToGlobal(Offset.zero) - overlayBox.localToGlobal(Offset.zero);
    return (rect: topLeft & box.size, overlaySize: overlayBox.size);
  }

  Future<({Rect rect, Size overlaySize})?> _makeRoomBelow(
    BuildContext ctx,
    ({Rect rect, Size overlaySize}) measured,
    double messageCardHeight,
  ) async {
    final requiredSpace = _requiredBubbleSpace(messageCardHeight);
    final missing =
        requiredSpace - (measured.overlaySize.height - measured.rect.bottom);
    if (missing <= 0) return measured;

    final scrollable = Scrollable.maybeOf(ctx);
    final position = scrollable?.position;
    if (position == null) return measured;
    final targetOffset = (position.pixels + missing)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((targetOffset - position.pixels).abs() < 0.5) return measured;

    await position.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !ctx.mounted) return null;
    return _readTargetRect(ctx);
  }

  double _messageCardHeight(Size overlaySize) {
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final maxTextWidth = (overlaySize.width - 64)
        .clamp(0.0, double.infinity)
        .toDouble();

    double textHeight(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout(maxWidth: maxTextWidth);
      return painter.height;
    }

    final stepHeight = textHeight(
      '${widget.stepIndex + 1}/$kOnboardingTotalSteps',
      const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
    );
    final titleHeight = textHeight(
      widget.title,
      const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
    );
    final bodyHeight = textHeight(
      widget.body,
      const TextStyle(fontSize: 13, height: 1.4),
    );
    return 32 + stepHeight + 6 + titleHeight + 6 + bodyHeight + 10 + 48;
  }

  @override
  Widget build(BuildContext context) {
    final rect = _targetRect;
    if (rect == null) {
      return Positioned.fill(
        child: AbsorbPointer(child: SizedBox.expand(key: _overlayKey)),
      );
    }

    final screenSize = _localSize ?? MediaQuery.sizeOf(context);
    const margin = 16.0;
    final messageCardHeight = _messageCardHeight(screenSize);
    final requiredSpace = _requiredBubbleSpace(messageCardHeight);

    final spaceBelow = screenSize.height - rect.bottom;
    final spaceAbove = rect.top;
    final _BubblePlacement placement;
    if (widget.forceBubbleBelow || spaceBelow >= requiredSpace) {
      placement = _BubblePlacement.below;
    } else if (spaceAbove >= requiredSpace) {
      placement = _BubblePlacement.above;
    } else {
      placement = spaceBelow >= spaceAbove
          ? _BubblePlacement.below
          : _BubblePlacement.above;
    }

    double cardMaxHeight(double availableHeight) {
      return (availableHeight - _bubbleArrowSize - _spotlightMargin * 2)
          .clamp(0.0, messageCardHeight)
          .toDouble();
    }

    final bubbleBelow = _MessageCard(
      stepIndex: widget.stepIndex,
      title: widget.title,
      body: widget.body,
      maxHeight: cardMaxHeight(screenSize.height - rect.bottom),
    );
    final bubbleAbove = _MessageCard(
      stepIndex: widget.stepIndex,
      title: widget.title,
      body: widget.body,
      maxHeight: cardMaxHeight(rect.top),
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
              child: _SpotlightHitTestBlocker(
                passthroughRect: hole,
                onBackgroundTap: widget.onBackgroundTap,
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
                    const Icon(
                      Icons.arrow_upward,
                      color: Colors.white,
                      size: _bubbleArrowSize,
                    ),
                    bubbleBelow,
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
                    bubbleAbove,
                    const Icon(
                      Icons.arrow_downward,
                      color: Colors.white,
                      size: _bubbleArrowSize,
                    ),
                  ],
                ),
              ),
            },
          ],
        ),
      ),
    );
  }
}

enum _BubblePlacement { below, above }

class _SpotlightHitTestBlocker extends LeafRenderObjectWidget {
  const _SpotlightHitTestBlocker({
    required this.passthroughRect,
    this.onBackgroundTap,
  });

  final Rect passthroughRect;
  final VoidCallback? onBackgroundTap;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSpotlightHitTestBlocker(
      passthroughRect,
      onBackgroundTap: onBackgroundTap,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderSpotlightHitTestBlocker renderObject,
  ) {
    renderObject.passthroughRect = passthroughRect;
    renderObject.backgroundTapCallback = onBackgroundTap;
  }
}

class _RenderSpotlightHitTestBlocker extends RenderBox {
  _RenderSpotlightHitTestBlocker(this._passthroughRect, {this.onBackgroundTap});

  Rect _passthroughRect;
  VoidCallback? onBackgroundTap;
  int? _trackedPointer;
  Offset? _trackedStartPosition;
  bool _exceededTouchSlop = false;

  set passthroughRect(Rect value) {
    if (_passthroughRect == value) return;
    _passthroughRect = value;
    markNeedsPaint();
  }

  set backgroundTapCallback(VoidCallback? value) {
    if (onBackgroundTap == value) return;
    onBackgroundTap = value;
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  bool hitTestSelf(Offset position) => !_passthroughRect.contains(position);

  @override
  void handleEvent(PointerEvent event, covariant HitTestEntry entry) {
    if (event is PointerDownEvent) {
      _trackedPointer = event.pointer;
      _trackedStartPosition = event.localPosition;
      _exceededTouchSlop = false;
      return;
    }

    if (event.pointer != _trackedPointer) return;

    if (event is PointerMoveEvent) {
      final start = _trackedStartPosition;
      if (start != null &&
          (event.localPosition - start).distance > kTouchSlop) {
        _exceededTouchSlop = true;
      }
      return;
    }

    if (event is PointerUpEvent) {
      if (!_exceededTouchSlop) {
        onBackgroundTap?.call();
      }
      _clearTrackedPointer();
      return;
    }

    if (event is PointerCancelEvent) {
      _clearTrackedPointer();
    }
  }

  void _clearTrackedPointer() {
    _trackedPointer = null;
    _trackedStartPosition = null;
    _exceededTouchSlop = false;
  }
}

class _MessageCard extends ConsumerWidget {
  const _MessageCard({
    required this.stepIndex,
    required this.title,
    required this.body,
    required this.maxHeight,
  });

  final int stepIndex;
  final String title;
  final String body;
  final double maxHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = Column(
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
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: const Text(
              '다시 보지 않기',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
        ),
      ],
    );

    return ConstrainedBox(
      key: const ValueKey('coach-mark-message-card'),
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(child: content),
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
