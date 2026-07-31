import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/filter_chip_row.dart';
import '../../core/widgets/quest_type_badge.dart';
import '../../state/progress_notifier.dart';
import '../../state/repository_providers.dart';

const _filters = [
  FilterChipOption(key: 'all', label: '전체'),
  FilterChipOption(key: 'nature', label: '🌲 자연탐험'),
  FilterChipOption(key: 'food', label: '🍜 미식방문'),
  FilterChipOption(key: 'history', label: '🏛️ 역사문화'),
  FilterChipOption(key: 'active', label: '🧗 액티비티'),
  FilterChipOption(key: 'healing', label: '☕ 힐링'),
];

class QuestListScreen extends ConsumerStatefulWidget {
  const QuestListScreen({super.key});

  @override
  ConsumerState<QuestListScreen> createState() => _QuestListScreenState();
}

class _QuestListScreenState extends ConsumerState<QuestListScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(questRepositoryProvider);
    final quests = _filter == 'all' ? repo.all() : repo.byType(_filter);
    final progress = ref.watch(progressProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('퀘스트'),
        titleSpacing: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilterChipRow(
              options: _filters,
              selectedKey: _filter,
              onSelected: (key) => setState(() => _filter = key),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: quests.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final quest = quests[index];
                final region = ref
                    .read(regionRepositoryProvider)
                    .byId(quest.region);
                final done = progress.isCompleted(quest.id);
                final typeEmoji = questTypeStyles[quest.type]?.emoji ?? '📍';
                return ListTile(
                  onTap: () => context.push('/quest/${quest.id}'),
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  // 관광지 썸네일(TourAPI) — 이미지가 없으면 기존 유형 이모지 원형 그대로.
                  leading: AppNetworkImage(
                    url: quest.imageUrl,
                    width: 48,
                    height: 48,
                    borderRadius: BorderRadius.circular(24),
                    placeholderEmoji: typeEmoji,
                  ),
                  title: Text(
                    quest.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('📍 ${region?.name ?? quest.region}'),
                  trailing: done
                      ? const Icon(
                          Icons.check_circle,
                          color: AppColors.primaryDark,
                        )
                      : QuestTypeBadge(type: quest.type),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
