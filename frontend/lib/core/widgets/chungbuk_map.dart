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

/// SVG path의 정점 목록만 추출한다(Z는 닫힘 표시일 뿐 좌표가 없으므로 제외).
List<Offset> _parsePathPoints(String d) {
  final points = <Offset>[];
  final tokens = RegExp(r'([MLZ])([^MLZ]*)').allMatches(d);
  for (final token in tokens) {
    if (token.group(1) == 'Z') continue;
    final coords = token
        .group(2)!
        .trim()
        .split(RegExp(r'[\s,]+'))
        .where((s) => s.isNotEmpty)
        .map(double.parse)
        .toList();
    for (var i = 0; i + 1 < coords.length; i += 2) {
      points.add(Offset(coords[i], coords[i + 1]));
    }
  }
  return points;
}

/// 폴리곤의 넓이 가중 중심(centroid) — 지역 이름을 도형의 실제 한가운데에
/// 배치하기 위함. 단순 정점 평균은 오목한 해안선 형태의 시·군 경계에서
/// 한쪽으로 쏠릴 수 있어 사용하지 않는다.
Offset polygonCentroid(String pathData) {
  final points = _parsePathPoints(pathData);
  var area = 0.0;
  var cx = 0.0;
  var cy = 0.0;
  for (var i = 0; i < points.length; i++) {
    final p0 = points[i];
    final p1 = points[(i + 1) % points.length];
    final cross = p0.dx * p1.dy - p1.dx * p0.dy;
    area += cross;
    cx += (p0.dx + p1.dx) * cross;
    cy += (p0.dy + p1.dy) * cross;
  }
  area *= 0.5;
  if (area == 0) {
    final avgX = points.map((p) => p.dx).reduce((a, b) => a + b) / points.length;
    final avgY = points.map((p) => p.dy).reduce((a, b) => a + b) / points.length;
    return Offset(avgX, avgY);
  }
  return Offset(cx / (6 * area), cy / (6 * area));
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

    // 지역 경계가 서로 맞닿아 있어 라벨이 이웃 지역 쪽으로 살짝 걸치면 뒤에
    // 칠해지는 이웃 지역 도형에 가려 글자가 잘려 보인다. 그래서 모든 지역을
    // 먼저 칠하고, 라벨은 그 위에 별도 패스로 그린다.
    for (final region in kRegionsInMapOrder) {
      final path = parseSimpleSvgPath(region.path);
      final colors = mapFillColors(regionProgress[region.id] ?? 0);
      canvas.drawPath(path, Paint()..color = colors.background);
      canvas.drawPath(path, strokePaint);
    }

    for (final region in kRegionsInMapOrder) {
      final colors = mapFillColors(regionProgress[region.id] ?? 0);
      final labelCenter = polygonCentroid(region.path);
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
          labelCenter.dx - textPainter.width / 2,
          labelCenter.dy - textPainter.height / 2,
        ),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ChungbukMapPainter oldDelegate) =>
      oldDelegate.regionProgress != regionProgress;
}
