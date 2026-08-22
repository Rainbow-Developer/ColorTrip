import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_network_image.dart';
import '../../data/location/location_gateway.dart' show distanceMeters;
import '../../data/models/festival.dart';
import '../../data/models/quest.dart';
import '../../state/repository_providers.dart';

/// 행사 상세 바텀시트(docs/specs/095-festival-info) — 포스터·기간·장소·소개와
/// 행사 좌표에서 가까운 추천 퀘스트 3개(거리 표시)를 보여준다.
void showFestivalDetailSheet(
  BuildContext context, {
  required Festival festival,
  required String regionId,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => FestivalDetailSheet(festival: festival, regionId: regionId),
  );
}

class FestivalDetailSheet extends ConsumerWidget {
  const FestivalDetailSheet({
    super.key,
    required this.festival,
    required this.regionId,
  });

  final Festival festival;
  final String regionId;

  String _period() {
    String md(DateTime d) => '${d.month}.${d.day}';
    return '${md(festival.startDate)} ~ ${md(festival.endDate)}';
  }

  /// 행사 좌표에서 가까운 순으로 좌표 있는 지역 퀘스트 3개.
  List<(Quest, double)> _nearbyQuests(WidgetRef ref) {
    final lat = festival.lat;
    final lng = festival.lng;
    if (lat == null || lng == null) return const [];
    final quests = ref.read(questRepositoryProvider).byRegion(regionId);
    final withDistance = [
      for (final q in quests)
        if (q.lat != null && q.lng != null)
          (q, distanceMeters(lat, lng, q.lat!, q.lng!)),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    return withDistance.take(3).toList();
  }

  static String _formatDistance(double meters) => meters < 1000
      ? '${meters.round()}m'
      : '${(meters / 1000).toStringAsFixed(1)}km';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final ongoing = festival.isOngoing(today);
    final nearby = _nearbyQuests(ref);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            AppNetworkImage(
              url: festival.posterUrl,
              height: 150,
              borderRadius: BorderRadius.circular(14),
              placeholderEmoji: '🎪',
              placeholderEmojiSize: 40,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: ongoing ? AppColors.primaryDark : Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    ongoing ? '진행 중' : 'D-${festival.daysUntilStart(today)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    festival.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${_period()} · ${festival.placeName}',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            if (festival.description case final description?) ...[
              const SizedBox(height: 12),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: AppColors.textBody,
                ),
              ),
            ],
            if (nearby.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                '행사장 근처 추천 퀘스트',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              for (final (quest, distance) in nearby)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Text(
                    questTypeStyles[quest.type]?.emoji ?? '📍',
                    style: const TextStyle(fontSize: 20),
                  ),
                  title: Text(
                    quest.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${quest.place} · ${_formatDistance(distance)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () {
                    Navigator.of(context).pop();
                    context.push('/quest/${quest.id}');
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }
}
