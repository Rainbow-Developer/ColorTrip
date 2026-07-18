import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../state/home_tutorial_notifier.dart';
import '../../state/progress_notifier.dart';
import '../../state/progress_state.dart';
import '../../state/repository_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final dna = ref
        .watch(dnaRepositoryProvider)
        .byId(progress.dnaType ?? 'nature');
    final tutorialDismissed = ref.watch(homeTutorialDismissedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('마이')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.mapEmpty,
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    progress.nickname ?? kDefaultNickname,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${dna.icon} ${dna.name}',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.timeline_outlined),
            title: const Text('타임라인'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/timeline'),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('내 정보 수정'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/profile/edit'),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.help_outline),
            title: const Text('홈 화면 가이드 다시 보기'),
            subtitle: const Text('지도 사용법 안내를 홈 화면에서 다시 표시해요'),
            value: !tutorialDismissed,
            onChanged: (value) {
              final notifier = ref.read(homeTutorialDismissedProvider.notifier);
              if (value) {
                notifier.showAgain();
              } else {
                notifier.dismiss(persist: true);
              }
            },
          ),
          const Divider(height: 32),
          Text(
            '완료 퀘스트 ${progress.completedQuestIds.length}개 · 리워드 ${ref.read(progressProvider.notifier).totalReward()}P',
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
