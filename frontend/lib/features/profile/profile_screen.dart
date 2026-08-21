import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/network/dio_client.dart';
import '../../core/widgets/app_network_image.dart';
import '../../state/onboarding_tour_notifier.dart';
import '../../state/auth_controller.dart';
import '../../state/progress_notifier.dart';
import '../../state/progress_state.dart';
import '../../state/repository_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final user = ref.watch(currentUserProvider);
    final dna = ref
        .watch(dnaRepositoryProvider)
        .byId(user?.dna ?? progress.dnaType ?? 'nature');
    final tour = ref.watch(onboardingTourProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('마이')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              AppNetworkImage(
                url: ref.watch(resolveUploadUrlProvider)(user?.profileImage),
                width: 64,
                height: 64,
                borderRadius: BorderRadius.circular(32),
                placeholderEmoji: '👤',
                placeholderEmojiSize: 26,
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.nickname ?? kDefaultNickname,
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
            leading: const Icon(Icons.logout),
            title: const Text('로그아웃'),
            onTap: () async {
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) context.go('/splash');
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('내 정보 수정'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/profile/edit'),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.help_outline),
            title: const Text('이용 가이드 다시 보기'),
            subtitle: const Text('지도·퀘스트·여행 시작 사용법 안내를 처음부터 다시 봐요'),
            value: !tour.isDone,
            onChanged: (value) async {
              final notifier = ref.read(onboardingTourProvider.notifier);
              if (value) {
                await notifier.restart();
                if (context.mounted) context.go('/home');
              } else {
                notifier.skipForever();
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
