import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/quest.dart';
import '../../state/place_providers.dart';
import 'app_network_image.dart';

/// 퀘스트 썸네일 — 지역 이미지 맵(TourAPI 실시간)에서 퀘스트의 tourContentId로
/// URL을 찾아 [AppNetworkImage]로 그린다(docs/specs/090-realtime-tour-place-info).
/// 로딩 중·조회 실패·contentId 없음(수제 퀘스트)은 모두 placeholder.
class QuestImage extends ConsumerWidget {
  const QuestImage({
    super.key,
    required this.quest,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholderEmoji,
    this.placeholderEmojiSize = 24,
    this.placeholderText,
  });

  final Quest quest;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final String? placeholderEmoji;
  final double placeholderEmojiSize;
  final String? placeholderText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentId = quest.tourContentId;
    final url = contentId == null
        ? null
        : ref
              .watch(regionPlaceImagesProvider(quest.region))
              .asData
              ?.value[contentId];
    return AppNetworkImage(
      url: url,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      placeholderEmoji: placeholderEmoji,
      placeholderEmojiSize: placeholderEmojiSize,
      placeholderText: placeholderText,
    );
  }
}
