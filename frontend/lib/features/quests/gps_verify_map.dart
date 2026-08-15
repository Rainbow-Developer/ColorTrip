/// GPS 인증 화면의 위치 도식 — 퀘스트 지점·인증 반경·내 위치를 그린다.
///
/// 배경으로 **퀘스트 좌표 기준 정적 지도**(VWorld 이미지 API)를 서버 프록시에서 받아 깔고,
/// 그 위에 반경 원과 내 위치를 얹는다. 지도 SDK를 쓰지 않는 이유는 성능이 아니라 불변식이다 —
/// SDK는 현재 위치 기준으로 타일을 요청해 좌표가 지도 사업자에게 나간다
/// (docs/specs/050-quest-verification/location-law-review.md — "단말을 벗어나면 안 된다").
///
/// **내 위치는 이 위젯 안에서만 화면 좌표가 되고 어떤 네트워크 호출에도 실리지 않는다.**
/// 배경 이미지 URL은 퀘스트 id만 담는다.
///
/// 배경을 받지 못하면(키 미설정·오프라인) 격자 도식으로 내려앉는다 — 배경은 참고용이고
/// 인증 판정과 무관하다.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// 서버가 만드는 배경 지도의 크기·줌 — `backend/app/core/config.py`의
/// `map_image_width`/`map_image_height`/`map_zoom`과 **같아야 한다**. 어긋나면 반경 원과
/// 내 위치가 지도와 어긋난다. 백엔드 테스트가 이 값을 고정한다.
const int kMapImageWidthPx = 640;
const int kMapImageHeightPx = 360;
const int kMapZoom = 15;

/// 퀘스트 지점을 원점으로 한 내 위치의 상대 위치(미터). `dx` = 동쪽, `dy` = 북쪽.
///
/// 등거리 근사다 — 위도 1도를 약 111,320m로 보고 경도는 위도에 따라 축소한다. 인증 반경이
/// 수백 m 규모라 이 오차(수 km에서 1% 미만)는 도식 표시에 영향이 없다. **거리 판정은 이
/// 함수가 아니라 하버사인(`distanceMeters`)이 담당한다** — 판정과 표시를 섞지 않는다.
Offset questRelativeOffsetMeters({
  required double questLat,
  required double questLng,
  required double myLat,
  required double myLng,
}) {
  const metersPerDegree = 111320.0;
  final north = (myLat - questLat) * metersPerDegree;
  final east =
      (myLng - questLng) * metersPerDegree * math.cos(questLat * math.pi / 180);
  return Offset(east, north);
}

/// 도식이 담아야 할 반경(미터) — 퀘스트 반경과 내 위치가 모두 보이도록 정한다.
///
/// 배경 지도가 **없을 때**만 쓴다. 지도가 깔리면 축척이 그 이미지에 고정되므로
/// [mapImageSpanMeters]를 쓴다.
double mapSpanMeters({required double radiusMeters, double? distanceMeters}) {
  final base = radiusMeters * 1.35;
  if (distanceMeters == null) return base;
  return math.max(base, distanceMeters * 1.25);
}

/// 웹 메르카토르 축척 — 줌 레벨·위도에서 픽셀당 미터.
///
/// 2026-08-15에 VWorld 응답으로 실측 확인했다: center를 256px에 해당하는 경도만큼 옮긴
/// 이미지가 원본의 절반과 픽셀 단위로 일치했다(워터마크 영역 제외). 위도 37·줌 15에서
/// 약 3.82m/px.
double metersPerPixel({required double latitude, required int zoom}) =>
    156543.03392 *
    math.cos(latitude * math.pi / 180) /
    math.pow(2, zoom).toDouble();

/// 배경 지도 이미지가 가로로 담는 실제 거리(m).
///
/// 위젯이 이미지를 어떤 크기로 늘리든 **담는 거리는 그대로**이므로, 오버레이는 이 값만
/// 알면 화면 크기와 무관하게 지도와 정렬된다.
double mapImageSpanMeters({required double latitude}) =>
    kMapImageWidthPx * metersPerPixel(latitude: latitude, zoom: kMapZoom);

/// 내 위치·퀘스트 지점·인증 반경 도식.
class GpsVerifyMap extends StatelessWidget {
  const GpsVerifyMap({
    super.key,
    required this.questLat,
    required this.questLng,
    required this.radiusMeters,
    this.mapImageUrl,
    this.myLat,
    this.myLng,
    this.distanceMeters,
    this.isWithinRadius = false,
  });

  final double questLat;
  final double questLng;
  final double radiusMeters;

  /// 배경 지도 URL(`/quests/{id}/map`). null이거나 로드에 실패하면 격자 도식으로 그린다.
  final String? mapImageUrl;

  /// 내 위치 — 아직 측위 전이거나 실패했으면 null이고, 그때는 퀘스트 지점과 반경만 그린다.
  final double? myLat;
  final double? myLng;

  /// 하버사인 실측 거리(m). 축척 계산과 안내 문구에 쓴다.
  final double? distanceMeters;
  final bool isWithinRadius;

  @override
  Widget build(BuildContext context) {
    final myLat = this.myLat;
    final myLng = this.myLng;
    final relative = (myLat == null || myLng == null)
        ? null
        : questRelativeOffsetMeters(
            questLat: questLat,
            questLng: questLng,
            myLat: myLat,
            myLng: myLng,
          );
    final url = mapImageUrl;

    return AspectRatio(
      aspectRatio: kMapImageWidthPx / kMapImageHeightPx,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url != null)
              Image.network(
                url,
                fit: BoxFit.cover,
                // 배경을 못 받아도 인증은 계속돼야 한다 — 격자 도식으로 내려앉는다.
                errorBuilder: (_, _, _) => _overlay(relative, hasMap: false),
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : Container(color: AppColors.verifyMapBg),
              ),
            // 배경이 있으면 지도 축척에 맞춰, 없으면 자동 축척으로 그린다.
            if (url != null)
              _overlay(relative, hasMap: true)
            else
              _overlay(relative, hasMap: false),
            _chips(relative),
          ],
        ),
      ),
    );
  }

  Widget _overlay(Offset? relative, {required bool hasMap}) => CustomPaint(
    painter: _GpsVerifyMapPainter(
      radiusMeters: radiusMeters,
      // 지도가 깔리면 축척은 이미지가 담는 거리로 고정된다. 없으면 두 점이 보이도록 맞춘다.
      spanMeters: hasMap
          ? mapImageSpanMeters(latitude: questLat)
          : mapSpanMeters(
                  radiusMeters: radiusMeters,
                  distanceMeters: distanceMeters,
                ) *
                2,
      relativeMeters: relative,
      isWithinRadius: isWithinRadius,
      drawBackground: !hasMap,
    ),
  );

  Widget _chips(Offset? relative) => Stack(
    children: [
      Positioned(
        left: 12,
        top: 10,
        child: _Chip(
          label: '인증 반경 ${_formatMeters(radiusMeters)}',
          color: AppColors.textMuted,
        ),
      ),
      Positioned(
        right: 12,
        bottom: 10,
        child: relative == null
            ? const _Chip(label: '현재 위치 확인 중', color: AppColors.textMuted)
            : _Chip(
                label: isWithinRadius
                    ? '반경 안에 있어요'
                    : '약 ${_formatMeters(distanceMeters ?? 0)} 떨어짐',
                color: isWithinRadius
                    ? AppColors.primaryDark
                    : AppColors.textMuted,
              ),
      ),
    ],
  );
}

String _formatMeters(double meters) => meters >= 1000
    ? '${(meters / 1000).toStringAsFixed(1)}km'
    : '${meters.round()}m';

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.timelineLine),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}

class _GpsVerifyMapPainter extends CustomPainter {
  const _GpsVerifyMapPainter({
    required this.radiusMeters,
    required this.spanMeters,
    required this.relativeMeters,
    required this.isWithinRadius,
    required this.drawBackground,
  });

  final double radiusMeters;

  /// 도식이 가로로 담는 거리(m).
  final double spanMeters;

  /// 퀘스트 지점 기준 내 위치(m). null이면 내 위치를 그리지 않는다.
  final Offset? relativeMeters;
  final bool isWithinRadius;

  /// 배경 지도가 없을 때만 회색 배경·격자를 그린다.
  final bool drawBackground;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // 가로가 담는 거리 기준 — 배경 지도가 가로 폭에 맞춰 들어오므로 그 축척을 따른다.
    final pixelsPerMeter = size.width / spanMeters;
    final radiusPx = radiusMeters * pixelsPerMeter;

    if (drawBackground) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = AppColors.verifyMapBg,
      );
      _drawGrid(canvas, size, center, radiusPx);
    }

    canvas.drawCircle(
      center,
      radiusPx,
      Paint()..color = AppColors.primaryDark.withValues(alpha: 0.12),
    );
    canvas.drawCircle(
      center,
      radiusPx,
      Paint()
        ..color = AppColors.primaryDark.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final relative = relativeMeters;
    if (relative != null) {
      // 화면 y축은 아래가 +이므로 북쪽(+dy)을 위로 뒤집는다.
      final raw =
          center +
          Offset(relative.dx * pixelsPerMeter, -relative.dy * pixelsPerMeter);
      // 배경 지도는 축척이 고정이라 멀리 있으면 화면을 벗어난다. 그때는 가장자리에 붙여
      // 방향이라도 보여준다 — 거리 값은 칩에 있다.
      final clamped = Offset(
        raw.dx.clamp(10.0, size.width - 10),
        raw.dy.clamp(10.0, size.height - 10),
      );
      final isOffScreen = clamped != raw;

      canvas.drawLine(
        center,
        clamped,
        Paint()
          ..color = AppColors.textMuted.withValues(alpha: 0.6)
          ..strokeWidth = 1.2,
      );
      final meColor = isWithinRadius
          ? AppColors.primaryDark
          : AppColors.textMuted;
      if (isOffScreen) {
        _drawArrow(canvas, center, clamped, meColor);
      } else {
        canvas.drawCircle(
          clamped,
          8,
          Paint()..color = meColor.withValues(alpha: 0.25),
        );
        canvas.drawCircle(clamped, 4.5, Paint()..color = meColor);
        canvas.drawCircle(
          clamped,
          4.5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }

    _drawQuestMarker(canvas, center);
  }

  /// 화면 밖의 내 위치 — 가장자리에 방향 삼각형으로 표시한다.
  void _drawArrow(Canvas canvas, Offset from, Offset at, Color color) {
    final angle = math.atan2(at.dy - from.dy, at.dx - from.dx);
    final path = Path();
    const size = 8.0;
    for (final offset in [0.0, 2.4, -2.4]) {
      final point =
          at +
          Offset(math.cos(angle + offset), math.sin(angle + offset)) * size;
      offset == 0.0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  /// 축척을 눈으로 가늠하게 하는 옅은 격자 — 한 칸이 인증 반경과 같다.
  void _drawGrid(Canvas canvas, Size size, Offset center, double step) {
    if (step <= 4) return; // 너무 촘촘하면 배경만 지저분해진다
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var x = center.dx; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var x = center.dx - step; x > 0; x -= step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = center.dy; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (var y = center.dy - step; y > 0; y -= step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawQuestMarker(Canvas canvas, Offset center) {
    canvas.drawCircle(center, 6, Paint()..color = AppColors.primaryDark);
    canvas.drawCircle(
      center,
      6,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_GpsVerifyMapPainter oldDelegate) =>
      oldDelegate.radiusMeters != radiusMeters ||
      oldDelegate.spanMeters != spanMeters ||
      oldDelegate.relativeMeters != relativeMeters ||
      oldDelegate.isWithinRadius != isWithinRadius ||
      oldDelegate.drawBackground != drawBackground;
}
