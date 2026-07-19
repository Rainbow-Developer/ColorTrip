import 'package:flutter/material.dart';

import '../../data/static/regions_data.dart';
import '../constants.dart';

/// SVG path "M x,y L x,y ... Z" 형식만 지원하는 최소 파서 — 지도 데이터가 M/L/Z만 사용하므로
/// flutter_svg 등 외부 패키지 없이 이걸로 충분하다([plan.md] 지도 렌더링 결정 A).
Path parseSimpleSvgPath(String d) {
  final path = Path();
  final tokens = RegExp(r'([MLZ])([^MLZ]*)').allMatches(d);
  for (final token in tokens) {
    final command = token.group(1)!;
    if (command == 'Z') {
      path.close();
      continue;
    }
    final coords = token
        .group(2)!
        .trim()
        .split(RegExp(r'[\s,]+'))
        .where((s) => s.isNotEmpty)
        .map(double.parse)
        .toList();
    for (var i = 0; i + 1 < coords.length; i += 2) {
      final x = coords[i];
      final y = coords[i + 1];
      if (command == 'M' && i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
  }
  return path;
}

/// 지역 진행도(n)별 색칠 단계 — 0 회색 / 1 라이트그린 / 2+ 진그린([description.md]).
({Color background, Color label}) mapFillColors(int progress) {
  if (progress <= 0) {
    return (background: AppColors.mapEmpty, label: AppColors.mapEmptyLabel);
  }
  if (progress == 1) {
    return (background: AppColors.mapStep1, label: AppColors.mapStep1Label);
  }
  return (background: AppColors.mapStep2, label: AppColors.mapStep2Label);
}

/// 충북 11개 시·군 색칠 지도. viewBox 원본 좌표계는 "10 10 480 460".
class ChungbukMap extends StatelessWidget {
  const ChungbukMap({
    super.key,
    required this.regionProgress,
    this.onRegionTap,
  });

  static const double _viewBoxMinX = 10;
  static const double _viewBoxMinY = 10;
  static const double _viewBoxWidth = 480;
  static const double _viewBoxHeight = 460;

  final Map<String, int> regionProgress;
  final ValueChanged<String>? onRegionTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _viewBoxWidth / _viewBoxHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            onTapUp: (details) => _handleTap(details.localPosition, size),
            child: CustomPaint(
              size: size,
              painter: _ChungbukMapPainter(regionProgress: regionProgress),
            ),
          );
        },
      ),
    );
  }

  void _handleTap(Offset local, Size size) {
    final onTap = onRegionTap;
    if (onTap == null) return;
    final scaleX = size.width / _viewBoxWidth;
    final scaleY = size.height / _viewBoxHeight;
    final svgPoint = Offset(
      local.dx / scaleX + _viewBoxMinX,
      local.dy / scaleY + _viewBoxMinY,
    );
    for (final region in kRegionsInMapOrder) {
      if (parseSimpleSvgPath(region.path).contains(svgPoint)) {
        onTap(region.id);
        return;
      }
    }
  }
}

class _ChungbukMapPainter extends CustomPainter {
  _ChungbukMapPainter({required this.regionProgress});

  final Map<String, int> regionProgress;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(
      size.width / ChungbukMap._viewBoxWidth,
      size.height / ChungbukMap._viewBoxHeight,
    );
    canvas.translate(-ChungbukMap._viewBoxMinX, -ChungbukMap._viewBoxMinY);

    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    // 지역 도형(채우기+테두리)을 먼저 전부 그리고, 라벨은 그 뒤에 별도 패스로 그린다.
    // 한 지역씩 도형+라벨을 번갈아 그리면 나중에 그려지는 인접 지역의 도형이 먼저 그린
    // 지역의 라벨을 덮어버릴 수 있다(예: 충주시가 음성군 라벨 위를 가림).
    for (final region in kRegionsInMapOrder) {
      final path = parseSimpleSvgPath(region.path);
      final colors = mapFillColors(regionProgress[region.id] ?? 0);
      canvas.drawPath(path, Paint()..color = colors.background);
      canvas.drawPath(path, strokePaint);
    }

    for (final region in kRegionsInMapOrder) {
      final colors = mapFillColors(regionProgress[region.id] ?? 0);
      final textPainter = TextPainter(
        text: TextSpan(
          text: region.name,
          style: TextStyle(
            color: colors.label,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(
          region.labelX - textPainter.width / 2,
          region.labelY - textPainter.height / 2,
        ),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ChungbukMapPainter oldDelegate) =>
      oldDelegate.regionProgress != regionProgress;
}
