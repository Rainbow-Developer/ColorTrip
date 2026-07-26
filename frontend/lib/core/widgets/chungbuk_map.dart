import 'package:flutter/foundation.dart';
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

/// [parseSimpleSvgPath]와 좌표 파싱을 공유하되, `Path` 대신 정점 목록을 반환한다
/// (다각형 중심 계산용).
List<Offset> _parseSvgPathPoints(String d) {
  final points = <Offset>[];
  final tokens = RegExp(r'([MLZ])([^MLZ]*)').allMatches(d);
  for (final token in tokens) {
    final command = token.group(1)!;
    if (command == 'Z') continue;
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

/// 다각형의 무게중심 — 라벨을 지역 도형 정 가운데에 자동으로 배치하기 위해 사용한다
/// (수동으로 좌표를 하나하나 맞추면 지역마다 어긋나기 쉽다). 넓이가 0에 가까운 퇴화
/// 폴리곤(매우 가늘고 긴 조각)은 정점 평균으로 대체한다.
Offset _polygonCentroid(List<Offset> points) {
  if (points.length < 3) {
    return points.isEmpty ? Offset.zero : points.first;
  }
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
  if (area.abs() < 1e-6) {
    final avgX =
        points.map((p) => p.dx).reduce((a, b) => a + b) / points.length;
    final avgY =
        points.map((p) => p.dy).reduce((a, b) => a + b) / points.length;
    return Offset(avgX, avgY);
  }
  return Offset(cx / (6 * area), cy / (6 * area));
}

/// 지역별 파싱된 Path·중심 좌표 캐시 — 지역 도형 데이터는 정적이라 절대 바뀌지 않으므로,
/// 매 프레임/매 탭마다 SVG 문자열을 다시 파싱하고 중심을 재계산할 필요가 없다.
final Map<String, ({Path path, Offset centroid})> _regionGeometryCache = {
  for (final region in kRegionsInMapOrder)
    region.id: (
      path: parseSimpleSvgPath(region.path),
      centroid: _polygonCentroid(_parseSvgPathPoints(region.path)),
    ),
};

/// 채도(0.0 미완료 ~ 1.0 완전 채색)를 5단계 팔레트 인덱스(1~5)로 양자화한다.
/// 0이면 아직 채색되지 않은 지역이라 회색을 쓴다.
int _mapColorLevel(double saturation) {
  if (saturation <= 0) return 0;
  return (saturation.clamp(0.0, 1.0) * 5).ceil().clamp(1, 5);
}

/// 지역 채색 색상 — 퀘스트 개수가 아니라 완료한 퀘스트의 난이도(reward) 비율로 정해지는
/// 채도([ProgressState.regionSaturation] 참고, KAN-44)를 5단계로 양자화해, 지역별 고유
/// 팔레트([regionMapColors], KAN-51)에서 해당 단계 색을 고른다.
({Color background, Color label}) mapFillColors(String regionId, double saturation) {
  final level = _mapColorLevel(saturation);
  final palette = regionMapColors[regionId];
  final background =
      (level == 0 || palette == null) ? AppColors.mapEmpty : palette[level - 1];
  // 고정 임계값 대신 배경의 실제 명도로 라벨 색을 고른다. regionMapColors 팔레트가
  // 전 지역 파스텔 톤이라(레벨5도 luminance 최대 0.69) 0.4는 너무 낮아서 레벨5에서도
  // 회색 글씨가 나오는 지역이 있었다 — 모든 지역이 레벨5에서 흰 글씨가 되도록 0.7로 올렸다.
  final label = background.computeLuminance() > 0.7
      ? AppColors.mapEmptyLabel
      : Colors.white;
  return (background: background, label: label);
}

/// 충북 11개 시·군 색칠 지도. viewBox 원본 좌표계는 "10 10 480 460".
class ChungbukMap extends StatelessWidget {
  const ChungbukMap({
    super.key,
    required this.regionSaturation,
    this.onRegionTap,
  });

  static const double _viewBoxMinX = 10;
  static const double _viewBoxMinY = 10;
  static const double _viewBoxWidth = 480;
  static const double _viewBoxHeight = 460;

  final Map<String, double> regionSaturation;
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
              painter: _ChungbukMapPainter(regionSaturation: regionSaturation),
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
      if (_regionGeometryCache[region.id]!.path.contains(svgPoint)) {
        onTap(region.id);
        return;
      }
    }
  }
}

class _ChungbukMapPainter extends CustomPainter {
  _ChungbukMapPainter({required this.regionSaturation});

  final Map<String, double> regionSaturation;

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
    final fillPaint = Paint();
    for (final region in kRegionsInMapOrder) {
      final path = _regionGeometryCache[region.id]!.path;
      final colors = mapFillColors(region.id, regionSaturation[region.id] ?? 0);
      fillPaint.color = colors.background;
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, strokePaint);
    }

    for (final region in kRegionsInMapOrder) {
      final colors = mapFillColors(region.id, regionSaturation[region.id] ?? 0);
      final centroid = _regionGeometryCache[region.id]!.centroid;
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
          centroid.dx - textPainter.width / 2,
          centroid.dy - textPainter.height / 2,
        ),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ChungbukMapPainter oldDelegate) =>
      !mapEquals(oldDelegate.regionSaturation, regionSaturation);
}
