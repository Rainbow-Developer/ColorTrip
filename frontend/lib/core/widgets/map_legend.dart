import 'package:flutter/material.dart';

import '../../data/models/region.dart';
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

/// 지역 대표 이모지 — 팔레트 팝업의 원형 배지에 쓴다. kRegionsInMapOrder와 1:1 대응한다.
const Map<String, String> _regionPaletteEmoji = {
  'jincheon': '🌸',
  'eumseong': '🍊',
  'jeungpyeong': '🌲',
  'cheongju': '🏯',
  'goesan': '🕳️',
  'chungju': '🏞️',
  'jecheon': '🌼',
  'danyang': '🪻',
  'boeun': '⛰️',
  'okcheon': '🪷',
  'yeongdong': '🌳',
};

/// 지역별 색상 팔레트 팝업 — 지역마다 원형 아이콘 배지 + 이름 + 5단계 팔레트를 한 줄로 보여준다.
class _RegionPaletteDialog extends StatelessWidget {
  const _RegionPaletteDialog();

  @override
  Widget build(BuildContext context) {
    final dialogWidth = MediaQuery.sizeOf(context).width * 0.88;
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: dialogWidth,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceMuted,
                      shape: BoxShape.circle,
                    ),
                    child: const Text('🎨', style: TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '지역별 색상 팔레트',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textHeading,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '왼쪽부터 인증한 여행 수 1회 → 5회예요 ✨',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceMuted,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final region in kRegionsInMapOrder)
                        _PaletteRow(region: region),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🍃', style: TextStyle(fontSize: 15)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: 'TIP  ',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const TextSpan(
                              text: '1은 가장 연한 색상, 5는 가장 진한 색상이에요.',
                            ),
                          ],
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textBody,
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
    );
  }
}

/// 팔레트 팝업의 지역 1건 — 원형 이모지 배지(그 지역 1단계 색) + 이름 + 구분선 + 5단계 팔레트.
class _PaletteRow extends StatelessWidget {
  const _PaletteRow({required this.region});

  final Region region;

  @override
  Widget build(BuildContext context) {
    final colors = regionMapColors[region.id] ?? const <Color>[];
    final emoji = _regionPaletteEmoji[region.id] ?? '📍';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.isNotEmpty ? colors.first : AppColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 48,
            child: Text(
              region.name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          Container(
            width: 1,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: AppColors.border,
          ),
          Expanded(
            child: Row(
              children: [
                for (var i = 0; i < colors.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: colors[i],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
