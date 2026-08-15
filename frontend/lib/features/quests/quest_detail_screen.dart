import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/network/dio_client.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/quest_type_badge.dart';
import '../../state/progress_notifier.dart';
import '../../state/repository_providers.dart';

/// 퀘스트 상세 — 정보 전용 화면. Figma 스펙(2026-07-08/09 공유) 반영: 관광지 이미지 placeholder,
/// 지역/유형/인증방식 배지, "퀘스트 조건" 카드. 퀘스트를 수행/인증하는 버튼은 여기 없다 —
/// 여행 시작하기로 담은 퀘스트를 실제로 수행하는 진입점은 지역 개요("여행하기") 화면의
/// "내 여행 퀘스트" 목록이다(2026-07-09 사용자 확정).
///
/// 완료한 퀘스트를 "히스토리 보기"로 들어오면(KAN-46), 사진 인증 퀘스트는 관광지 이미지
/// placeholder 대신 실제로 업로드했던 사진을, 완료 시각과 함께 보여준다.
///
/// 참고: 이 Figma 스펙에는 보상(P) 표시가 없어 화면에서 뺐다 — 필요하면 다시 노출 위치를 정해야 한다.
class QuestDetailScreen extends ConsumerWidget {
  const QuestDetailScreen({super.key, required this.questId});

  final String questId;

  static const _conditionEmoji = {
    'photo': '📷',
    'gps': '📍',
    'quiz': '✅',
    'qr': '🔳',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quest = ref.watch(questRepositoryProvider).byId(questId);
    if (quest == null) {
      return const Scaffold(body: Center(child: Text('퀘스트를 찾을 수 없어요')));
    }
    final region = ref.watch(regionRepositoryProvider).byId(quest.region);
    final progress = ref.watch(progressProvider);
    final done = progress.isCompleted(quest.id);
    final completedEntry = done ? progress.timelineEntryFor(quest.id) : null;
    final resolvedPhotoUrl = ref.watch(resolveUploadUrlProvider)(
      completedEntry?.photoUrl,
    );
    final conditionEmoji = _conditionEmoji[quest.verify] ?? '📍';

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('퀘스트 상세'),
        titleSpacing: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                // 완료 사진(히스토리)이 있으면 그것을 우선, 없으면 관광지 이미지(TourAPI),
                // 그마저 없으면 기존 placeholder.
                child: completedEntry?.photo != null
                    ? Image.memory(completedEntry!.photo!, fit: BoxFit.cover)
                    : resolvedPhotoUrl != null
                    ? Image.network(
                        resolvedPhotoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const _ImagePlaceholder(),
                      )
                    : AppNetworkImage(
                        url: quest.imageUrl,
                        placeholderText: '관광지 이미지',
                      ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    quest.title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (done)
                  const Icon(Icons.check_circle, color: AppColors.primaryDark),
              ],
            ),
            if (completedEntry != null) ...[
              const SizedBox(height: 4),
              Text(
                '${completedEntry.date} ${completedEntry.time}에 인증 완료',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [

                QuestTypeBadge(type: quest.type),
                VerifyBadge(verify: quest.verify),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '퀘스트 조건',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  for (final condition in quest.conditions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '$conditionEmoji $condition',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              quest.desc,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: AppColors.imagePlaceholderBg),
      child: const Center(
        child: Text(
          '관광지 이미지',
          style: TextStyle(color: AppColors.formPlaceholder),
        ),
      ),
    );
  }
}
