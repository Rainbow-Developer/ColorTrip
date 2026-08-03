import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../constants.dart';

/// 네트워크 이미지 공용 위젯 — TourAPI 대표 이미지 등 원격 이미지를 디스크 캐시와 함께
/// 보여준다(docs/specs/045-quest-region-images).
///
/// [url]이 null/빈 문자열이면 네트워크 요청 없이 기존 화면들과 같은 placeholder
/// (회색 [AppColors.imagePlaceholderBg] 배경 + 가운데 이모지/텍스트)를 그린다 —
/// 정적 데이터에 이미지가 아직 없는 항목도 기존 UI 그대로 보여야 한다.
/// 로딩 중·로드 실패 시에도 같은 placeholder로 폴백한다.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholderEmoji,
    this.placeholderEmojiSize = 24,
    this.placeholderText,
  });

  /// 이미지 URL. null이거나 공백뿐이면 placeholder만 그린다.
  final String? url;

  final double? width;
  final double? height;
  final BoxFit fit;

  /// null이면 클립 없이 그린다(바깥에서 이미 ClipRRect로 감싸는 경우).
  final BorderRadius? borderRadius;

  /// placeholder 가운데에 표시할 이모지(예: 퀘스트 유형 이모지). [placeholderText]보다 우선.
  final String? placeholderEmoji;

  /// 이모지 크기 — 썸네일 크기에 맞춘다(작은 원형 48px는 기본값, 카드 4:3은 32 등).
  final double placeholderEmojiSize;

  /// placeholder 가운데에 표시할 안내 텍스트(예: '관광지 이미지').
  final String? placeholderText;

  Widget _buildPlaceholder() {
    Widget? child;
    if (placeholderEmoji != null) {
      child = Text(
        placeholderEmoji!,
        style: TextStyle(fontSize: placeholderEmojiSize),
      );
    } else if (placeholderText != null) {
      child = Text(
        placeholderText!,
        style: const TextStyle(color: AppColors.formPlaceholder),
        textAlign: TextAlign.center,
      );
    }
    return Container(
      width: width,
      height: height,
      color: AppColors.imagePlaceholderBg,
      alignment: child == null ? null : Alignment.center,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    final image = url == null || url.trim().isEmpty
        ? _buildPlaceholder()
        : CachedNetworkImage(
            imageUrl: url,
            width: width,
            height: height,
            fit: fit,
            fadeInDuration: const Duration(milliseconds: 150),
            placeholder: (_, _) => _buildPlaceholder(),
            errorWidget: (_, _, _) => _buildPlaceholder(),
          );
    final radius = borderRadius;
    if (radius == null) return image;
    return ClipRRect(borderRadius: radius, child: image);
  }
}
