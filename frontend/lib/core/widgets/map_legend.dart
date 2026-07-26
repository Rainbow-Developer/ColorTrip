import 'package:flutter/material.dart';

import '../constants.dart';

/// 지도 색칠 범례 — 지도 자체는 이제 채도를 5단계로 양자화해서 칠하므로
/// ([core/widgets/chungbuk_map.dart]의 mapFillColors, KAN-51), 연속 그라데이션 바 대신
/// 그 5단계를 그대로 보여주는 스와치를 쓴다. 실제 지역 팔레트는 지역마다 색조가 달라
/// 대표색으로 쓸 수 없어, 범례 전용 파스텔 그린 톤([mapLegendColors])을 쓴다.
class MapLegend extends StatelessWidget {
  const MapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Text(
          '여행 농도',
          style: TextStyle(fontSize: 10, color: AppColors.tripMutedBadgeFg),
        ),
        const SizedBox(width: 4),
        for (final color in mapLegendColors)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Container(
              width: 16,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    );
  }
}
