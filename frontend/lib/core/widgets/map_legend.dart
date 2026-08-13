import 'package:flutter/material.dart';

import '../constants.dart';

/// 지도 색칠 범례 — 지도는 채도를 5단계로 양자화해서 칠하므로
/// ([core/widgets/chungbuk_map.dart]의 mapFillColors, KAN-51) 그 5단계를 스와치로 보여준다.
/// 실제 지역 팔레트는 지역마다 색조가 달라 대표색으로 쓸 수 없어, 범례 전용 파스텔 그린
/// 톤([mapLegendColors])을 쓴다.
///
/// 스와치가 나타내는 값은 그 지역에서 **퀘스트를 1개 이상 인증한 여행(여정) 수**다
/// ([ProgressState.regionSaturation], [055-journey-map-coloring], KAN-73) — 여행 1회가 한
/// 단계씩 진해져 5회에 최대 채도가 되므로, 오른쪽 표기도 "5회+"로 맞춘다. 여행을 완주해야
/// 세는 게 아니므로 라벨도 "완료"가 아니라 "인증한 여행 수"다(좁은 가로 폭에 맞춘 축약 —
/// 전체 정의는 위 스펙 참조).
class MapLegend extends StatelessWidget {
  const MapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Text(
          '인증한 여행 수',
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
        const SizedBox(width: 1),
        const Text(
          '5회+',
          style: TextStyle(fontSize: 10, color: AppColors.tripMutedBadgeFg),
        ),
      ],
    );
  }
}
