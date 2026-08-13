import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/domain_repository.dart';
import 'progress_notifier.dart';
import 'repository_providers.dart';

class DomainController extends AsyncNotifier<DomainSnapshot> {
  String? _pendingCreateSignature;
  String? _pendingCreateRequestId;

  @override
  FutureOr<DomainSnapshot> build() {
    listenSelf((_, next) {
      next.when(
        data: (snapshot) =>
            ref.read(progressProvider.notifier).replaceFromServer(snapshot),
        loading: () {},
        error: (_, _) {},
      );
    });
    return _fetch();
  }

  Future<DomainSnapshot> refresh() async {
    final snapshot = await _fetch();
    state = AsyncData(snapshot);
    return snapshot;
  }

  Future<void> createJourney({
    required String regionKey,
    required List<String> questKeys,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final signature = [
      regionKey,
      questKeys.join(','),
      title,
      startDate.toIso8601String(),
      endDate.toIso8601String(),
    ].join('|');
    if (_pendingCreateSignature != signature) {
      _pendingCreateSignature = signature;
      _pendingCreateRequestId = _uuidV4();
    }
    await ref
        .read(domainRepositoryProvider)
        .createJourney(
          clientRequestId: _pendingCreateRequestId!,
          regionKey: regionKey,
          questKeys: questKeys,
          title: title,
          startDate: startDate,
          endDate: endDate,
        );
    await refresh();
    _pendingCreateSignature = null;
    _pendingCreateRequestId = null;
  }

  Future<void> replaceJourneyQuests({
    required String journeyId,
    required List<String> questKeys,
  }) async {
    await ref
        .read(domainRepositoryProvider)
        .replaceJourneyQuests(journeyId: journeyId, questKeys: questKeys);
    await refresh();
  }

  /// 좌표 파라미터는 없다 — 위치 인증은 단말에서 판정하고 좌표를 서버로 보내지 않는다
  /// (docs/specs/050-quest-verification/location-law-review.md, KAN-77).
  Future<QuestVerification> verifyQuest({
    required String questKey,
    String? journeyId,
    String? photoUrl,
    String? answer,
    String? qrPayload,
  }) async {
    final result = await ref
        .read(domainRepositoryProvider)
        .verifyQuest(
          questKey: questKey,
          journeyId: journeyId,
          photoUrl: photoUrl,
          answer: answer,
          qrPayload: qrPayload,
        );
    if (result.verified) {
      try {
        await refresh();
      } on Object {
        // 인증 결과는 이미 서버에 저장됐다. 다음 동기화에서 화면 상태를 복구한다.
      }
    }
    return result;
  }

  Future<QuestVerification> uploadAndVerifyPhoto({
    required String questKey,
    required Uint8List bytes,
    String mimeType = 'image/jpeg',
    String? journeyId,
  }) async {
    final repository = ref.read(domainRepositoryProvider);
    final photoUrl = await repository.uploadPhoto(bytes, mimeType: mimeType);
    return verifyQuest(
      questKey: questKey,
      journeyId: journeyId,
      photoUrl: photoUrl,
    );
  }

  Future<DomainSnapshot> _fetch() =>
      ref.read(domainRepositoryProvider).fetchSnapshot();
}

final domainControllerProvider =
    AsyncNotifierProvider<DomainController, DomainSnapshot>(
      DomainController.new,
      retry: (_, _) => null,
    );

String _uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int value) => value.toRadixString(16).padLeft(2, '0');
  final value = bytes.map(hex).join();
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
      '${value.substring(12, 16)}-${value.substring(16, 20)}-'
      '${value.substring(20)}';
}
