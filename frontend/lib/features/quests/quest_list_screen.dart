import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/quest_type_badge.dart';
import '../../state/progress_notifier.dart';
import '../../state/repository_providers.dart';

class _QuestTypeOption {
  const _QuestTypeOption({required this.key, required this.label, this.iconAsset});

  final String key;
  final String label;
  final String? iconAsset;
}

const _typeOptions = [
  _QuestTypeOption(key: 'all', label: '전체'),
  _QuestTypeOption(
    key: 'nature',
    label: '자연탐험형',
    iconAsset: 'assets/images/quest_type_nature.svg',
  ),
  _QuestTypeOption(
    key: 'food',
    label: '미식탐방형',
    iconAsset: 'assets/images/quest_type_food.svg',
  ),
  _QuestTypeOption(
    key: 'history',
    label: '역사문화형',
    iconAsset: 'assets/images/quest_type_history.svg',
  ),
  _QuestTypeOption(
    key: 'active',
    label: '액티비티형',
    iconAsset: 'assets/images/quest_type_active.svg',
  ),
  _QuestTypeOption(
    key: 'healing',
    label: '힐링형',
    iconAsset: 'assets/images/quest_type_healing.svg',
  ),
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
      appBar: AppBar(leading: const AppBackButton(), title: const Text('퀘스트'), titleSpacing: 0),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _typeOptions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final option = _typeOptions[index];
                  return _QuestTypeOptionTile(
                    option: option,
                    selected: _filter == option.key,
                    onTap: () => setState(() => _filter = option.key),
                  );
                },
              ),
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
                return ListTile(
                  onTap: () => context.push('/quest/${quest.id}'),
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: Text(
                    questTypeStyles[quest.type]?.emoji ?? '📍',
                    style: const TextStyle(fontSize: 24),
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

class _QuestTypeOptionTile extends StatelessWidget {
  const _QuestTypeOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _QuestTypeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: option.iconAsset == null
                    ? AppColors.surfaceMuted
                    : Colors.white,
                border: Border.all(
                  color: selected ? AppColors.primaryDark : Colors.transparent,
                  width: 2,
                ),
              ),
              child: option.iconAsset != null
                  ? SvgPicture.asset(option.iconAsset!, fit: BoxFit.cover)
                  : const Icon(Icons.apps, color: AppColors.textMuted),
            ),
            const SizedBox(height: 6),
            Text(
              option.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primaryDark : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
