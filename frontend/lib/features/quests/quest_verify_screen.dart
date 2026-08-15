import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_toast.dart';
import '../../data/location/location_gateway.dart';
import '../../data/media/photo_picker_gateway.dart';
import '../../data/models/quest.dart' show Quest, kDefaultVerifyRadiusMeters;
import '../../data/repositories/domain_repository.dart';
import '../../state/domain_controller.dart';
import '../../state/repository_providers.dart';
import 'gps_verify_map.dart';

/// 퀘스트 수행(인증) 화면 — 여행 시작하기로 담은 퀘스트를 지역 개요("여행하기")의
/// "내 여행 퀘스트" 목록에서 탭하면 여기로 온다(2026-07-09 사용자 확정 — 퀘스트 상세에는
/// 더 이상 수행 버튼이 없다). 사진/GPS/OX퀴즈 유형별 UI는 Figma 스펙(2026-07-08 공유) 반영.
/// 사진은 실제 업로드하고 GPS는 현재 위치를 조회해 서버 검증을 수행한다.
class QuestVerifyScreen extends ConsumerWidget {
  const QuestVerifyScreen({super.key, required this.questId, this.journeyId});

  final String questId;
  final String? journeyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quest = ref.watch(questRepositoryProvider).byId(questId);
    if (quest == null) {
      return const Scaffold(body: Center(child: Text('퀘스트를 찾을 수 없어요')));
    }

    // 이 퀘스트를 담은 그 지역 여행을 찾아 인증을 여정에 연결한다. 진행중 여행을 먼저 보되,
    // 없으면 완료된 여행도 쓴다 — 여행 기간이 지나 완료로 넘어간 뒤에 남은 퀘스트를 인증하면
    // (KAN-73 완료 판정) 진행중 여행이 없어 여정 연결이 끊기고, 지도 채색 집계에도 빠진다.
    final candidates =
        ref
            .watch(domainControllerProvider)
            .value
            ?.journeys
            .where(
              (journey) =>
                  journey.regionKey == quest.region &&
                  journey.questKeys.contains(quest.id),
            )
            .toList() ??
        const [];
    final journeyId =
        this.journeyId ??
        (candidates
                    .where((journey) => journey.status == 'in_progress')
                    .firstOrNull ??
                candidates.firstOrNull)
            ?.id;

    switch (quest.verify) {
      case 'gps':
        return _GpsVerifyBody(
          questTitle: quest.title,
          questLat: quest.lat,
          questLng: quest.lng,
          radiusMeters: quest.verifyRadius ?? kDefaultVerifyRadiusMeters,
          onVerified: () => _verifyGps(context, ref, quest, journeyId),
        );
      case 'quiz':
        return _QuizVerifyBody(
          quest: quest,
          fallbackLocation: '/region/${quest.region}',
          onVerified: (answer) => _verify(
            context,
            ref,
            quest,
            journeyId: journeyId,
            answer: answer ? 'O' : 'X',
          ),
        );
      case 'qr':
        return _QrVerifyBody(
          fallbackLocation: '/region/${quest.region}',
          onVerified: (payload) => _verify(
            context,
            ref,
            quest,
            journeyId: journeyId,
            qrPayload: payload,
          ),
        );
      default:
        return _PhotoVerifyBody(
          questTitle: quest.title,
          onVerified: (photo) =>
              _verifyPhoto(context, ref, quest, photo, journeyId),
        );
    }
  }

  Future<bool?> _verify(
    BuildContext context,
    WidgetRef ref,
    Quest quest, {
    String? journeyId,
    String? photoUrl,
    String? answer,
    String? qrPayload,
  }) async {
    try {
      final result = await ref
          .read(domainControllerProvider.notifier)
          .verifyQuest(
            questKey: quest.id,
            journeyId: journeyId,
            photoUrl: photoUrl,
            answer: answer,
            qrPayload: qrPayload,
          );
      if (!context.mounted) return null;
      if (!result.verified) {
        showAppToast(context, result.reason ?? '인증 조건을 확인해주세요.');
      }
      return result.verified;
    } on Object {
      if (context.mounted) {
        showAppToast(context, '인증 결과를 저장하지 못했어요. 다시 시도해주세요.');
      }
      return null;
    }
  }

  /// 위치 인증 — 거리 판정을 **단말 안에서** 끝내고, 반경 이내일 때만 좌표 없이 완료를
  /// 요청한다 (docs/specs/050-quest-verification/location-law-review.md, KAN-77).
  ///
  /// 좌표를 서버로 보내면 저장하지 않더라도 위치정보법상 위치기반서비스사업 **신고
  /// 대상**이 된다. 팀이 채택한 설계(B안)는 좌표가 단말을 벗어나지 않는 것이고, 이
  /// 함수가 그 불변식이 지켜지는 지점이다 — `_verify`에 latitude·longitude를 넘기지
  /// 않는다. 서버도 gps 미션에 좌표가 오면 거절한다.
  Future<void> _verifyGps(
    BuildContext context,
    WidgetRef ref,
    Quest quest,
    String? journeyId,
  ) async {
    final questLat = quest.lat;
    final questLng = quest.lng;
    if (questLat == null || questLng == null) return; // 버튼이 비활성이라 도달하지 않는다

    try {
      final location = await ref.read(locationGatewayProvider).current();
      if (!context.mounted) return;

      final radius = quest.verifyRadius ?? kDefaultVerifyRadiusMeters;
      final distance = distanceMeters(
        location.latitude,
        location.longitude,
        questLat,
        questLng,
      );
      if (distance > radius) {
        // 반경 밖이면 서버를 부르지 않는다 — 좌표는 여기서 버려진다.
        showAppToast(
          context,
          '퀘스트 장소에서 약 ${_formatDistance(distance)} 떨어져 있어요 (인증 반경 ${radius}m)',
        );
        return;
      }

      final verified = await _verify(context, ref, quest, journeyId: journeyId);
      if (verified == true && context.mounted) {
        showAppToast(context, '퀘스트 완료! 지도가 칠해졌어요');
        _leaveVerifyScreen(context, '/region/${quest.region}');
      }
    } on LocationFailure catch (error) {
      if (context.mounted) await _showLocationFailure(context, ref, error);
    } on Object {
      if (context.mounted) {
        showAppToast(context, '현재 위치를 확인하지 못했어요. 다시 시도해주세요.');
      }
    }
  }

  /// 사진 인증 — 사진을 한 번만 올리고, 서버가 저장본을 읽어 비전 판정까지 수행한다
  /// (docs/specs/050-quest-verification, KAN-73). 판정 상세는 verify 응답으로 함께 오며
  /// 결과 화면이 신뢰도·사유·판정 제공자를 표시하도록 라우트 extra로 넘긴다.
  ///
  /// 실패는 화면 안에 사유를 남겨 재시도하게 하고(토스트는 사라져서 긴 판정 사유를 읽기
  /// 어렵다), 성공만 결과 화면으로 넘어간다. 반환값 = 표시할 실패 사유(null이면 성공).
  Future<String?> _verifyPhoto(
    BuildContext context,
    WidgetRef ref,
    Quest quest,
    PickedPhotoFile photo,
    String? journeyId,
  ) async {
    final QuestVerification result;
    try {
      result = await ref
          .read(domainControllerProvider.notifier)
          .uploadAndVerifyPhoto(
            questKey: quest.id,
            bytes: photo.bytes,
            mimeType: photo.mimeType,
            journeyId: journeyId,
          );
    } on Object {
      return '사진을 확인하지 못했어요. 잠시 후 다시 시도해주세요.';
    }
    if (!context.mounted) return null;

    if (!result.verified) {
      // 판정 사유(있으면)를 그대로 보여준다 — 무엇이 부족했는지가 재시도에 필요하다.
      final verdictReason = result.photoVerdict?.reason ?? '';
      if (verdictReason.isNotEmpty) return verdictReason;
      return result.reason ?? '퀘스트 조건에 맞는 사진인지 확인해주세요.';
    }

    context.push('/quest/$questId/verify/result', extra: result.photoVerdict);
    return null;
  }

  Future<void> _showLocationFailure(
    BuildContext context,
    WidgetRef ref,
    LocationFailure error,
  ) async {
    final gateway = ref.read(locationGatewayProvider);
    final (message, action) = switch (error.reason) {
      LocationFailureReason.serviceDisabled => (
        '기기의 위치 서비스를 켜주세요.',
        gateway.openLocationSettings,
      ),
      LocationFailureReason.permissionDeniedForever => (
        '앱 설정에서 위치 권한을 허용해주세요.',
        gateway.openAppSettings,
      ),
      LocationFailureReason.permissionDenied => (
        '위치 권한이 있어야 GPS 인증을 진행할 수 있어요.',
        null,
      ),
      LocationFailureReason.timeout => (
        '현재 위치 확인 시간이 초과됐어요. 실외에서 다시 시도해주세요.',
        null,
      ),
      LocationFailureReason.unavailable => (
        '현재 위치를 확인하지 못했어요. 다시 시도해주세요.',
        null,
      ),
    };
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('위치 확인 필요'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('확인'),
          ),
          if (action != null)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                action();
              },
              child: const Text('설정 열기'),
            ),
        ],
      ),
    );
  }
}

/// 반경 밖 안내에 쓰는 거리 표기 — 1km 이상은 km로 줄여 읽기 쉽게 한다.
String _formatDistance(double meters) => meters >= 1000
    ? '${(meters / 1000).toStringAsFixed(1)}km'
    : '${meters.round()}m';

/// 인증 성공 후 인증 화면을 닫고 들어왔던 화면(지역 개요 등)으로 돌아간다.
///
/// `context.go`로 목적지를 지정하면 라우터 스택이 교체돼 뒤로가기가 동작하지 않고 엉뚱한
/// 화면에 남았다(KAN-73 사용자 피드백). 스택이 비어 있는 경우(딥링크 등 직접 진입)에만
/// [fallbackLocation]으로 이동한다.
void _leaveVerifyScreen(BuildContext context, String fallbackLocation) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallbackLocation);
  }
}

class _QuizVerifyBody extends StatefulWidget {
  const _QuizVerifyBody({
    required this.quest,
    required this.onVerified,
    required this.fallbackLocation,
  });

  final Quest quest;
  final Future<bool?> Function(bool answer) onVerified;

  /// 돌아갈 화면이 스택에 없을 때만 쓰는 목적지.
  final String fallbackLocation;

  @override
  State<_QuizVerifyBody> createState() => _QuizVerifyBodyState();
}

class _QuizVerifyBodyState extends State<_QuizVerifyBody> {
  bool? _wrong;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('OX 퀴즈'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.quest.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                widget.quest.quizQuestion ?? '',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (_wrong == true) ...[
              const SizedBox(height: 8),
              const Text(
                '다시 생각해보세요.',
                style: TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : () => _answer(true),
                    child: const Text('O'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : () => _answer(false),
                    child: const Text('X'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _answer(bool value) async {
    setState(() {
      _busy = true;
      _wrong = false;
    });
    final verified = await widget.onVerified(value);
    if (!mounted) return;
    if (verified == true) {
      showAppToast(context, '퀘스트 완료! 지도가 칠해졌어요');
      _leaveVerifyScreen(context, widget.fallbackLocation);
      return;
    }
    if (verified == null) {
      setState(() => _busy = false);
      return;
    }
    setState(() {
      _busy = false;
      _wrong = true;
    });
  }
}

class _GpsVerifyBody extends ConsumerStatefulWidget {
  const _GpsVerifyBody({
    required this.questTitle,
    required this.questLat,
    required this.questLng,
    required this.radiusMeters,
    required this.onVerified,
  });

  final String questTitle;
  final double? questLat;
  final double? questLng;

  /// 인증 반경(m) — `Quest.verifyRadius`가 int라 여기도 int로 받고, 그리기에 넘길 때만
  /// double로 바꾼다.
  final int radiusMeters;
  final Future<void> Function() onVerified;

  bool get isReady => questLat != null && questLng != null;

  @override
  ConsumerState<_GpsVerifyBody> createState() => _GpsVerifyBodyState();
}

class _GpsVerifyBodyState extends ConsumerState<_GpsVerifyBody> {
  bool _busy = false;
  CurrentLocation? _myLocation;

  /// 측위가 끝났는지 — 실패해도 true다(무한 "확인 중"을 막는다).
  bool _locationResolved = false;

  @override
  void initState() {
    super.initState();
    // 화면에 들어오면 바로 측위해 도식에 내 위치를 그린다(KAN-87). 인증을 눌러야 측위하던
    // 이전 방식으로는 어느 쪽으로 얼마나 가야 하는지 인증 전에 알 수 없었다. 권한은 어차피
    // 인증에 필요하므로 요청 시점만 앞당긴 것이다.
    if (widget.isReady) unawaited(_locateForPreview());
  }

  /// 도식 표시용 측위 — **실패해도 사용자를 방해하지 않는다.** 권한 거부·서비스 꺼짐 안내는
  /// 실제 인증 시도(`_verifyGps`)가 담당하고, 여기서는 조용히 내 위치 없이 그린다.
  Future<void> _locateForPreview() async {
    try {
      final location = await ref.read(locationGatewayProvider).current();
      if (!mounted) return;
      setState(() {
        _myLocation = location;
        _locationResolved = true;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _locationResolved = true);
    }
  }

  /// 퀘스트 지점까지의 실측 거리(m) — 내 위치가 없으면 null.
  double? get _distance {
    final me = _myLocation;
    final lat = widget.questLat;
    final lng = widget.questLng;
    if (me == null || lat == null || lng == null) return null;
    return distanceMeters(me.latitude, me.longitude, lat, lng);
  }

  String get _locationSummary {
    final distance = _distance;
    if (distance != null) {
      return distance <= widget.radiusMeters
          ? '반경 안에 있어요'
          : '약 ${_formatDistance(distance)} 떨어져 있어요';
    }
    // 측위가 끝났는데 위치가 없으면 실패한 것이다 — 사유별 안내는 인증 시도가 담당한다.
    return _locationResolved ? '인증 버튼을 누르면 확인해요' : '확인 중...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('GPS 인증'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.questTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              '퀘스트에 설정된 인증 반경 안에서 시도해주세요.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 4),
            // 좌표 비전송은 사용자에게도 알린다(스토어 데이터 안전 섹션·처리방침과 일치).
            const Text(
              '현재 위치는 이 기기에서만 확인하고 서버로 보내지 않아요.',
              style: TextStyle(color: AppColors.primaryDark, fontSize: 12),
            ),
            const SizedBox(height: 16),
            if (widget.isReady)
              GpsVerifyMap(
                questLat: widget.questLat!,
                questLng: widget.questLng!,
                radiusMeters: widget.radiusMeters.toDouble(),
                myLat: _myLocation?.latitude,
                myLng: _myLocation?.longitude,
                distanceMeters: _distance,
                isWithinRadius:
                    (_distance ?? double.infinity) <= widget.radiusMeters,
              ),
            const SizedBox(height: 14),
            if (!widget.isReady)
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: Text(
                  '이 퀘스트는 위치 정보가 준비되지 않았어요.',
                  style: TextStyle(color: AppColors.danger, fontSize: 13),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '현재 위치',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        _locationSummary,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'ℹ️ GPS 정확도에 따라 인증이 지연될 수 있습니다. 실외에서 시도해주세요.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _busy || !widget.isReady
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      await widget.onVerified();
                      if (!mounted) return;
                      setState(() => _busy = false);
                      // 통과했으면 이 화면을 떠나므로, 여기 남았다는 건 반경 밖이라는 뜻이다.
                      // 도식을 갱신해 방금 측위한 위치를 보여준다.
                      await _locateForPreview();
                    },
              child: Text(_busy ? '현재 위치 확인 중...' : '현재 위치로 인증하기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrVerifyBody extends StatefulWidget {
  const _QrVerifyBody({
    required this.onVerified,
    required this.fallbackLocation,
  });

  final Future<bool?> Function(String payload) onVerified;

  /// 돌아갈 화면이 스택에 없을 때만 쓰는 목적지.
  final String fallbackLocation;

  @override
  State<_QrVerifyBody> createState() => _QrVerifyBodyState();
}

class _QrVerifyBodyState extends State<_QrVerifyBody> {
  bool _busy = false;

  Future<void> _verify(BarcodeCapture capture) async {
    if (_busy) return;
    final payload = capture.barcodes.firstOrNull?.rawValue;
    if (payload == null || payload.isEmpty) return;
    setState(() => _busy = true);
    final verified = await widget.onVerified(payload);
    if (!mounted) return;
    if (verified == true) {
      showAppToast(context, '퀘스트 완료! 지도가 칠해졌어요');
      _leaveVerifyScreen(context, widget.fallbackLocation);
      return;
    }
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('QR 인증'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('현장에 부착된 QR 코드를 프레임 안에 맞춰주세요.'),
            const SizedBox(height: 16),
            Expanded(
              child: MobileScanner(
                onDetect: _verify,
                errorBuilder: (_, _) => const Center(
                  child: Text(
                    '카메라를 열 수 없어요. 기기 권한을 확인한 뒤 다시 시도해주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoVerifyBody extends ConsumerStatefulWidget {
  const _PhotoVerifyBody({required this.questTitle, required this.onVerified});

  final String questTitle;

  /// 인증 요청 콜백 — 고른 사진으로 판정·완료 처리를 수행하고, 화면에 보여줄 실패 사유를
  /// 돌려준다(null이면 성공해 결과 화면으로 넘어갔다는 뜻).
  final Future<String?> Function(PickedPhotoFile photo) onVerified;

  @override
  ConsumerState<_PhotoVerifyBody> createState() => _PhotoVerifyBodyState();
}

class _PhotoVerifyBodyState extends ConsumerState<_PhotoVerifyBody> {
  // "업로드 가이드"에 안내한 상한과 맞춘다.
  static const _maxPhotoBytes = 5 * 1024 * 1024;

  PickedPhotoFile? _photo;
  bool _busy = false;

  /// 비전 모델이 거절한 사유(또는 통신 실패 안내) — 사진을 다시 고르면 지운다.
  /// 토스트로는 사라져서 긴 판정 사유를 읽기 어려워 화면 안에 남긴다.
  String? _failReason;

  Future<void> _pickPhoto(PhotoSource source) async {
    final PickedPhotoFile? picked;
    try {
      picked = await ref.read(photoPickerGatewayProvider).pick(source);
    } on PhotoPickFailure catch (failure) {
      if (mounted) showAppToast(context, failure.message);
      return;
    }
    if (picked == null || !mounted) return; // null = 사용자가 취소함(에러 아님)

    if (picked.bytes.length > _maxPhotoBytes) {
      showAppToast(context, '사진 용량은 5MB 이하만 가능해요.');
      return;
    }
    setState(() {
      _photo = picked;
      _failReason = null; // 새 사진을 골랐으니 지난 판정 사유는 지운다.
    });
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photo;
    // 확인 중에는 화면을 벗어나지 못하게 막는다 — 스크림으로 조작을 차단해두고 뒤로가기만
    // 열려 있으면, 서버 인증은 진행됐는데 결과 화면을 못 보고 나가게 된다.
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          leading: _busy
              ? const IconButton(
                  onPressed: null,
                  icon: Icon(Icons.arrow_back_ios_new, size: 18),
                )
              : const AppBackButton(),
          title: const Text('사진 인증'),
        ),
        // 업로드 + AI 판정을 기다리는 동안 화면 전체를 스크림으로 덮는다 — 버튼만
        // 비활성화하면 진행 중인지 알기 어렵다는 피드백(KAN-73).
        body: Stack(
          fit: StackFit.expand,
          children: [
            _form(photo),
            if (_busy) const _VerifyingScrim(message: '사진 확인 중...'),
          ],
        ),
      ),
    );
  }

  Widget _form(PickedPhotoFile? photo) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 미리보기를 원본 비율로 그리면 세로 사진에서 내용이 화면을 넘치므로 스크롤한다.
          // 인증 버튼은 스크롤 밖에 두어 사진 길이와 무관하게 같은 자리에 있게 한다.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.questTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '퀘스트 장소 사진을 업로드해주세요.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: () => _pickPhoto(PhotoSource.gallery),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: AppColors.uploadBoxBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: photo != null
                              ? AppColors.primaryDark
                              : AppColors.uploadBoxBorder,
                        ),
                      ),
                      alignment: Alignment.center,
                      // 고른 사진은 원본 비율 그대로 보여준다 — 고정 높이 + cover 로 채우면
                      // 무엇을 올렸는지 잘려 보여 판정 대상 확인이 어렵다. 다만 세로로 긴
                      // 사진이 화면을 다 차지하면 그 아래의 판정 실패 사유가 폴드 밖으로
                      // 밀리므로 높이 상한을 둔다. 상한을 두는 이상 fit 은 contain 이어야
                      // 한다 — fitWidth 로는 넘친 세로가 Clip.antiAlias 에 잘려 결국 crop 이
                      // 된다(KAN-83 리뷰).
                      child: photo != null
                          ? ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 320),
                              child: Image.memory(
                                photo.bytes,
                                width: double.infinity,
                                fit: BoxFit.contain,
                              ),
                            )
                          : const SizedBox(
                              height: 120,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('📷', style: TextStyle(fontSize: 28)),
                                  SizedBox(height: 4),
                                  Text(
                                    '사진 촬영 또는 갤러리 선택',
                                    style: TextStyle(
                                      color: AppColors.formPlaceholder,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _PhotoSourceButton(
                          label: '📷 카메라',
                          onTap: () => _pickPhoto(PhotoSource.camera),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PhotoSourceButton(
                          label: '🖼 갤러리',
                          onTap: () => _pickPhoto(PhotoSource.gallery),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '업로드 가이드',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '• 퀘스트 장소가 잘 보이는 사진\n• 최근 24시간 이내 촬영\n• 5MB 이하 JPG/PNG',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_failReason case final reason?) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.tripMutedBadgeBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        reason,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: photo != null && !_busy
                ? () async {
                    setState(() {
                      _busy = true;
                      _failReason = null;
                    });
                    final failReason = await widget.onVerified(photo);
                    if (!mounted) return;
                    setState(() {
                      _busy = false;
                      _failReason = failReason;
                    });
                  }
                : null,
            child: Text(
              _busy
                  ? '사진 확인 중...'
                  : photo != null
                  ? '사진으로 인증하기'
                  : '사진 선택 후 인증 가능',
            ),
          ),
        ],
      ),
    );
  }
}

/// 인증 진행 중 화면을 덮는 스크림 + 진행 카드(KAN-73).
///
/// 라우트(다이얼로그)가 아니라 화면 안의 레이어다 — 인증 성공 시 결과 화면을 push 하는데,
/// 다이얼로그였다면 그 위에 남거나 pop 순서가 엉킬 수 있다.
class _VerifyingScrim extends StatelessWidget {
  const _VerifyingScrim({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: ColoredBox(
        color: AppColors.verifyScrim,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textBody,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '잠시만 기다려주세요',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoSourceButton extends StatelessWidget {
  const _PhotoSourceButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ),
    );
  }
}
