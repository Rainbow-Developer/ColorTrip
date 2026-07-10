import 'package:flutter/material.dart';

import '../constants.dart';

/// 지도 색칠 범례 — 미방문/1개 완료/2개 이상([core/widgets/chungbuk_map.dart]의 mapFillColors 대응).
class MapLegend extends StatelessWidget {
  const MapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _LegendItem(color: AppColors.mapEmpty, label: '미방문'),
        SizedBox(width: 12),
        _LegendItem(color: AppColors.mapStep1, label: '1개 완료'),
        SizedBox(width: 12),
        _LegendItem(color: AppColors.mapStep2, label: '2개 이상'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.tripMutedBadgeFg,
          ),
        ),
      ],
    );
  }
}
