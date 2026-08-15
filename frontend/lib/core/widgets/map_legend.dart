import 'package:flutter/material.dart';

import '../../data/static/regions_data.dart';
import '../constants.dart';

/// 지도 색칠 범례 — 지역마다 팔레트가 달라([core/widgets/chungbuk_map.dart]의 mapFillColors,
/// KAN-51) 대표색 하나로 보여줄 수 없다. 그래서 여기서는 아이콘 링크만 두고, 실제 지역별
/// 팔레트는 [_RegionPaletteDialog] 팝업에서 보여준다.
///
/// 팔레트의 5단계가 나타내는 값은 그 지역에서 **퀘스트를 1개 이상 인증한 여행(여정) 수**다
/// ([ProgressState.regionSaturation], [055-journey-map-coloring], KAN-73) — 여행 1회가 한
/// 단계씩 진해져 5회에 최대 채도가 된다. 여행을 완주해야 세는 게 아니다.
///
/// KAN-69 이전에는 범례 전용 파스텔 그린 톤 스와치(mapLegendColors)를 "인증한 여행 수"
/// 라벨과 함께 인라인으로 보여줬는데, 지역별 실제 색을 확인할 수 없어 팝업으로 바꿨다.
class MapLegend extends StatelessWidget {
  const MapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => const _RegionPaletteDialog(),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline,
              size: 14,
              color: AppColors.tripMutedBadgeFg,
            ),
            SizedBox(width: 4),
            Text(
              '지역별 색상 팔레트 보기',
              style: TextStyle(fontSize: 10, color: AppColors.tripMutedBadgeFg),
            ),
          ],
        ),
      ),
    );
  }
}

/// 지역별 색상 팔레트 팝업 — 지역 이름 옆에 그 지역의 5단계 팔레트를 보여준다.
/// 팔레트 목록은 팝업 안에서 가운데 정렬하고, 제목은 그 목록의 지역 이름 위치에 맞춘다.
class _RegionPaletteDialog extends StatelessWidget {
  const _RegionPaletteDialog();

  // 이름 SizedBox(48) + 간격(4) + 스와치 5개(28 + 오른쪽 여백 4)의 고정 폭.
  static const _rowContentWidth = 48.0 + 4 + 5 * (28 + 4);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final titleIndent = ((constraints.maxWidth - _rowContentWidth) / 2)
                .clamp(0.0, double.infinity);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: EdgeInsets.only(left: titleIndent),
                  child: const Text(
                    '지역별 색상 팔레트',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 4),
                // 팔레트만 보여주면 색이 무엇을 뜻하는지 알 수 없다. KAN-73에서 범례 문구를
                // "인증한 여행 수"로 바로잡은 취지를 팝업에서도 유지한다.
                Padding(
                  padding: EdgeInsets.only(left: titleIndent),
                  child: const Text(
                    '왼쪽부터 인증한 여행 수 1회 → 5회+',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.tripMutedBadgeFg,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final region in kRegionsInMapOrder)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 48,
                                    child: Text(
                                      region.name,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  for (final color
                                      in regionMapColors[region.id] ??
                                          const <Color>[])
                                    Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: Container(
                                        width: 28,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: color,
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
