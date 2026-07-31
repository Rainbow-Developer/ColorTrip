import 'package:flutter/material.dart';

import '../constants.dart';

/// 지도 색칠 범례 — 지역 채색이 완료한 여행(여정) 수에 따라 연속적으로 진해지므로
/// ([ProgressState.regionSaturation]·[core/widgets/chungbuk_map.dart]의 mapFillColors 대응,
/// [055-journey-map-coloring]), 3단계 스와치 대신 미방문→완료를 잇는 그라데이션 바로
/// 그 흐름을 그대로 보여준다.
class MapLegend extends StatelessWidget {
  const MapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          '여행 완료 횟수',
          style: TextStyle(fontSize: 11, color: AppColors.tripMutedBadgeFg),
        ),
        const SizedBox(width: 8),
        const Text(
          '0회',
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
        // 3회 = 채도 100% 기준선(ProgressState._tripSaturationCap)과 맞춘 표기.
        const Text(
          '3회+',
          style: TextStyle(fontSize: 10, color: AppColors.tripMutedBadgeFg),
        ),
      ],
    );
  }
}
