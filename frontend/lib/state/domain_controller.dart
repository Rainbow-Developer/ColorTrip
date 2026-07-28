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
  FutureOr<DomainSnapshot> build() => _fetchAndApply();

  Future<DomainSnapshot> refresh() async {
    final snapshot = await _fetchAndApply();
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

  Future<QuestVerification> verifyQuest({
    required String questKey,
    String? journeyId,
    double? latitude,
    double? longitude,
    String? photoUrl,
    String? answer,
  }) async {
    final result = await ref
        .read(domainRepositoryProvider)
        .verifyQuest(
          questKey: questKey,
          journeyId: journeyId,
          latitude: latitude,
          longitude: longitude,
          photoUrl: photoUrl,
          answer: answer,
        );
    if (result.verified) await refresh();
    return result;
  }

  Future<QuestVerification> uploadAndVerifyPhoto({
    required String questKey,
    required Uint8List bytes,
    String? journeyId,
    double? latitude,
    double? longitude,
  }) async {
    final repository = ref.read(domainRepositoryProvider);
    final photoUrl = await repository.uploadPhoto(bytes);
    return verifyQuest(
      questKey: questKey,
      journeyId: journeyId,
      latitude: latitude,
      longitude: longitude,
      photoUrl: photoUrl,
    );
  }

  Future<DomainSnapshot> _fetchAndApply() async {
    final snapshot = await ref.read(domainRepositoryProvider).fetchSnapshot();
    ref.read(progressProvider.notifier).replaceFromServer(snapshot);
    return snapshot;
  }
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
