import 'package:flutter/material.dart';

import '../constants.dart';
import 'chungbuk_map.dart';

/// 지도 색칠 범례 — 지역 채색은 퀘스트 개수가 아니라 완료한 난이도 비율(0~100%)에 따라
/// 연속적으로 진해지므로([core/widgets/chungbuk_map.dart]의 mapFillColors 대응, KAN-44),
/// 대표값(0%/50%/100%) 3개로 그 흐름을 보여준다.
class MapLegend extends StatelessWidget {
  const MapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _LegendItem(color: mapFillColors(0).background, label: '미방문'),
        const SizedBox(width: 12),
        _LegendItem(color: mapFillColors(0.5).background, label: '진행중'),
        const SizedBox(width: 12),
        _LegendItem(color: mapFillColors(1).background, label: '완료'),
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
