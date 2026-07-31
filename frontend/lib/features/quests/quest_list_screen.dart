import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/chungbuk_map.dart';
import '../../data/models/quest.dart';
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
              height: 110,
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
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final quest = quests[index];
                final region = ref
                    .read(regionRepositoryProvider)
                    .byId(quest.region);
                final done = progress.isCompleted(quest.id);
                return _QuestCard(
                  quest: quest,
                  regionName: region?.name ?? quest.region,
                  done: done,
                  onTap: () => context.push('/quest/${quest.id}'),
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

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quest,
    required this.regionName,
    required this.done,
    required this.onTap,
  });

  final Quest quest;
  final String regionName;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typeStyle = questTypeStyles[quest.type];
    final tagColors = questTypeIconColors[quest.type];
    final regionColor = mapFillColors(quest.region, 1);

    return SizedBox(
      height: questCardHeight,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Container(
                      color: AppColors.imagePlaceholderBg,
                      alignment: Alignment.center,
                      child: Text(
                        typeStyle?.emoji ?? '📍',
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          quest.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _Tag(
                              label: regionName,
                              background: regionColor.background,
                              foreground: regionColor.label,
                            ),
                            if (tagColors != null && typeStyle != null) ...[
                              const SizedBox(width: 6),
                              _Tag(
                                label: typeStyle.label,
                                background: tagColors.background,
                                foreground: tagColors.foreground,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (done)
                  const Padding(
                    padding: EdgeInsets.only(right: 14),
                    child: Center(
                      child: Icon(Icons.check_circle, color: AppColors.primaryDark),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}
