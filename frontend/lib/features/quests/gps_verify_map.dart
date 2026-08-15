/// GPS 인증 화면의 위치 도식 — 퀘스트 지점·인증 반경·내 위치를 직접 그린다.
///
/// **외부 지도를 쓰지 않는다.** 구글·네이버·카카오·OSM 등은 현재 위치 기준으로 타일을
/// 요청하므로 좌표가 지도 사업자에게 전송되고, 그 순간 좌표 비전송 불변식이 깨진다
/// (docs/specs/050-quest-verification/location-law-review.md — "단말을 벗어나면 안 된다").
/// 위경도는 [questRelativeOffsetMeters]로 화면 좌표가 되어 painter에만 전달되고,
/// 어떤 네트워크 호출에도 실리지 않는다.
///
/// 렌더링 방식은 지도 채색(core/widgets/chungbuk_map.dart)과 같다 — 외부 패키지 없이
/// CustomPainter로 그린다.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants.dart';

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
/// 내 위치가 없으면 반경만 여유 있게 담고, 있으면 그 거리까지 담는다.
double mapSpanMeters({required double radiusMeters, double? distanceMeters}) {
  final base = radiusMeters * 1.35;
  if (distanceMeters == null) return base;
  return math.max(base, distanceMeters * 1.25);
}

/// 내 위치·퀘스트 지점·인증 반경 도식.
class GpsVerifyMap extends StatelessWidget {
  const GpsVerifyMap({
    super.key,
    required this.questLat,
    required this.questLng,
    required this.radiusMeters,
    this.myLat,
    this.myLng,
    this.distanceMeters,
    this.isWithinRadius = false,
  });

  final double questLat;
  final double questLng;
  final double radiusMeters;

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

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: CustomPaint(
          painter: _GpsVerifyMapPainter(
            radiusMeters: radiusMeters,
            spanMeters: mapSpanMeters(
              radiusMeters: radiusMeters,
              distanceMeters: distanceMeters,
            ),
            relativeMeters: relative,
            isWithinRadius: isWithinRadius,
          ),
          child: Stack(
            children: [
              Positioned(
                left: 12,
                top: 10,
                child: _Chip(
                  label: '인증 반경 ${_formatMeters(radiusMeters)}',
                  color: AppColors.textMuted,
                ),
              ),
              if (relative == null)
                const Positioned(
                  right: 12,
                  bottom: 10,
                  child: _Chip(label: '현재 위치 확인 중', color: AppColors.textMuted),
                )
              else
                Positioned(
                  right: 12,
                  bottom: 10,
                  child: _Chip(
                    label: isWithinRadius
                        ? '반경 안에 있어요'
                        : '약 ${_formatMeters(distanceMeters ?? 0)} 떨어짐',
                    color: isWithinRadius
                        ? AppColors.primaryDark
                        : AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
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
        color: Colors.white,
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
  });

  final double radiusMeters;
  final double spanMeters;

  /// 퀘스트 지점 기준 내 위치(m). null이면 내 위치를 그리지 않는다.
  final Offset? relativeMeters;
  final bool isWithinRadius;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.verifyMapBg);

    final center = Offset(size.width / 2, size.height / 2);
    // 짧은 변을 기준으로 축척을 잡아야 가로·세로 어느 쪽으로도 반경이 잘리지 않는다.
    final pixelsPerMeter = (math.min(size.width, size.height) / 2) / spanMeters;
    final radiusPx = radiusMeters * pixelsPerMeter;

    _drawGrid(canvas, size, center, pixelsPerMeter);

    canvas.drawCircle(
      center,
      radiusPx,
      Paint()..color = AppColors.primaryDark.withValues(alpha: 0.10),
    );
    canvas.drawCircle(
      center,
      radiusPx,
      Paint()
        ..color = AppColors.primaryDark.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final relative = relativeMeters;
    if (relative != null) {
      // 화면 y축은 아래가 +이므로 북쪽(+dy)을 위로 뒤집는다.
      final me =
          center +
          Offset(relative.dx * pixelsPerMeter, -relative.dy * pixelsPerMeter);
      canvas.drawLine(
        center,
        me,
        Paint()
          ..color = AppColors.textMuted.withValues(alpha: 0.5)
          ..strokeWidth = 1.2,
      );
      final meColor = isWithinRadius
          ? AppColors.primaryDark
          : AppColors.textMuted;
      canvas.drawCircle(
        me,
        7,
        Paint()..color = meColor.withValues(alpha: 0.25),
      );
      canvas.drawCircle(me, 4, Paint()..color = meColor);
      canvas.drawCircle(
        me,
        4,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    _drawQuestMarker(canvas, center);
  }

  /// 축척을 눈으로 가늠하게 하는 옅은 격자 — 한 칸이 인증 반경과 같다.
  void _drawGrid(
    Canvas canvas,
    Size size,
    Offset center,
    double pixelsPerMeter,
  ) {
    final step = radiusMeters * pixelsPerMeter;
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
      oldDelegate.isWithinRadius != isWithinRadius;
}
