import 'package:flutter/material.dart';

import '../constants.dart';

/// 지도 색칠 범례 — 지역 채색이 완료 개수가 아니라 난이도 비율(0~100%)로 연속적으로
/// 진해지므로([core/widgets/chungbuk_map.dart]의 mapFillColors 대응, KAN-44), 3단계 스와치 대신
/// 미방문→완료를 잇는 그라데이션 바로 그 흐름을 그대로 보여준다.
class MapLegend extends StatelessWidget {
  const MapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          '여행 채도',
          style: TextStyle(fontSize: 11, color: AppColors.tripMutedBadgeFg),
        ),
        const SizedBox(width: 8),
        const Text(
          '0%',
          style: TextStyle(fontSize: 10, color: AppColors.tripMutedBadgeFg),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: const LinearGradient(
                colors: [AppColors.mapEmpty, AppColors.primaryDark],
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        const Text(
          '100%',
          style: TextStyle(fontSize: 10, color: AppColors.tripMutedBadgeFg),
        ),
      ],
    );
  }
}
