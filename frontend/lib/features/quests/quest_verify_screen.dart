import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart' show DioException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_toast.dart';
import '../../data/models/quest.dart';
import '../../data/models/verification.dart';
import '../../data/repositories/verification_repository.dart';
import '../../state/progress_notifier.dart';
import '../../state/repository_providers.dart';

/// 퀘스트 수행(인증) 화면 — 여행 시작하기로 담은 퀘스트를 지역 개요("여행하기")의
/// "내 여행 퀘스트" 목록에서 탭하면 여기로 온다(2026-07-09 사용자 확정 — 퀘스트 상세에는
/// 더 이상 수행 버튼이 없다). 인증 4분기(docs/specs/050-quest-verification):
/// - photo: 사진을 서버 비전 모델(Gemini)에 보내 실제 판정을 받는다.
/// - gps: geolocator 실측위 + 온디바이스 거리 검증(좌표 서버 미전송).
/// - qr: mobile_scanner로 현장 QR을 스캔해 서버 서명 검증.
/// - quiz: OX 퀴즈(기존 유지 — plan.md 비목표).
class QuestVerifyScreen extends ConsumerWidget {
  const QuestVerifyScreen({super.key, required this.questId});

  final String questId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quest = ref.watch(questRepositoryProvider).byId(questId);
    if (quest == null) {
      return const Scaffold(body: Center(child: Text('퀘스트를 찾을 수 없어요')));
    }

    void completeAndPop() {
      ref.read(progressProvider.notifier).completeQuest(questId);
      showAppToast(context, '퀘스트 완료! 지도가 칠해졌어요');
      context.pop();
      context.pop();
    }

    void completeAndShowResult(Uint8List photo, PhotoVerdict verdict) {
      ref.read(progressProvider.notifier).completeQuest(questId, photo: photo);
      // 결과 화면은 라우트 extra로 실제 AI 판정값을 받는다([app/router.dart]).
      context.push('/quest/$questId/verify/result', extra: verdict);
    }

    switch (quest.verify) {
      case 'gps':
        return _GpsVerifyBody(quest: quest, onVerified: completeAndPop);
      case 'quiz':
        return _QuizVerifyBody(quest: quest, onVerified: completeAndPop);
      case 'qr':
        return _QrVerifyBody(quest: quest, onVerified: completeAndPop);
      default:
        return _PhotoVerifyBody(
          quest: quest,
          onVerified: completeAndShowResult,
        );
    }
  }
}

class _QuizVerifyBody extends StatefulWidget {
  const _QuizVerifyBody({required this.quest, required this.onVerified});

  final Quest quest;
  final VoidCallback onVerified;

  @override
  State<_QuizVerifyBody> createState() => _QuizVerifyBodyState();
}

class _QuizVerifyBodyState extends State<_QuizVerifyBody> {
  bool? _wrong;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('OX 퀴즈'),
        titleSpacing: 0,
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
                    onPressed: () => _answer(true),
                    child: const Text('O'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _answer(false),
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

  void _answer(bool value) {
    if (value == widget.quest.quizAnswer) {
      widget.onVerified();
    } else {
      setState(() => _wrong = true);
    }
  }
}

/// 위치 기반 인증(온디바이스) — geolocator로 실측위한 현재 좌표와 퀘스트 좌표의
/// 거리를 **단말 안에서만** 계산해 판정한다.
///
/// 좌표는 단말 내 거리 계산에만 쓰고 어떤 서버로도 전송하지 않는다
/// (docs/specs/050-quest-verification/location-law-review.md) — dio 호출에
/// 좌표를 싣지 말 것. 좌표가 서버에 닿는 순간 위치기반서비스사업 신고 대상이 된다.
class _GpsVerifyBody extends StatefulWidget {
  const _GpsVerifyBody({required this.quest, required this.onVerified});

  final Quest quest;
  final VoidCallback onVerified;

  @override
  State<_GpsVerifyBody> createState() => _GpsVerifyBodyState();
}

class _GpsVerifyBodyState extends State<_GpsVerifyBody> {
  /// 퀘스트에 반경이 없으면 쓰는 기본 인증 반경(m) — [Quest.verifyRadius] 문서 참고.
  static const _defaultRadiusMeters = 500;

  bool _locating = false;

  /// 서비스 꺼짐·권한 거부 등 측위 실패 안내 문구.
  String? _statusMessage;

  /// 권한이 영구 거부(deniedForever)라 앱 설정으로 보내야 하는 상태.
  bool _showOpenSettings = false;

  /// 측위는 성공했지만 반경 밖일 때의 실측 거리(m).
  double? _distanceMeters;

  bool get _hasCoords => widget.quest.lat != null && widget.quest.lng != null;

  int get _radiusMeters => widget.quest.verifyRadius ?? _defaultRadiusMeters;

  Future<void> _verifyLocation() async {
    final lat = widget.quest.lat;
    final lng = widget.quest.lng;
    if (lat == null || lng == null || _locating) return;

    setState(() {
      _locating = true;
      _statusMessage = null;
      _showOpenSettings = false;
      _distanceMeters = null;
    });

    try {
      // 1) 위치 서비스(GPS) 자체가 꺼져 있는지 확인.
      if (!await Geolocator.isLocationServiceEnabled()) {
        _fail('위치 서비스(GPS)가 꺼져 있어요. 기기 설정에서 켠 뒤 다시 시도해주세요.');
        return;
      }

      // 2) 권한 확인 → 거부 상태면 요청.
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _fail('위치 권한을 허용해야 현재 위치로 인증할 수 있어요.');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _fail('위치 권한이 거부되어 있어요. 설정에서 허용해주세요.', openSettings: true);
        return;
      }

      // 3) 실측위 — 얻은 좌표는 아래 거리 계산에만 쓰고 즉시 버린다.
      //    절대 서버로 보내지 않는다(location-law-review.md, 좌표 비전송 불변식).
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      // 4) 온디바이스 거리 판정(하버사인) — 반경 이내면 완료.
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        lat,
        lng,
      );
      if (!mounted) return;
      if (distance <= _radiusMeters) {
        widget.onVerified();
      } else {
        setState(() {
          _locating = false;
          _distanceMeters = distance;
        });
      }
    } on TimeoutException {
      _fail('위치를 확인하는 데 너무 오래 걸려요. 실외에서 다시 시도해주세요.');
    } catch (_) {
      _fail('현재 위치를 확인하지 못했어요. 잠시 후 다시 시도해주세요.');
    }
  }

  void _fail(String message, {bool openSettings = false}) {
    if (!mounted) return;
    setState(() {
      _locating = false;
      _statusMessage = message;
      _showOpenSettings = openSettings;
    });
  }

  String _formatDistance(double meters) => meters >= 1000
      ? '약 ${(meters / 1000).toStringAsFixed(1)}km'
      : '약 ${meters.round()}m';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('GPS 인증'),
        titleSpacing: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                children: [
                  Text(
                    widget.quest.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '퀘스트 장소 반경 ${_radiusMeters}m 이내에서 인증할 수 있어요.',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.verifyMapBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primaryDark.withValues(
                                alpha: 0.15,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primaryDark,
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Text('📍'),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.quest.place,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildStatusCard(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _hasCoords && !_locating ? _verifyLocation : null,
              child: _locating
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Text('현재 위치 확인 중...'),
                      ],
                    )
                  : const Text('현재 위치로 인증하기'),
            ),
          ],
        ),
      ),
    );
  }

  /// 상태별 안내 카드 — 좌표 없음 > 측위 중 > 반경 밖 > 실패 안내 > 기본 안내 순.
  Widget _buildStatusCard() {
    if (!_hasCoords) {
      return _infoCard(
        child: const Text(
          '이 퀘스트는 위치 정보가 준비되지 않았어요.\n다른 인증 퀘스트를 이용해주세요.',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      );
    }
    if (_locating) {
      return _infoCard(
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text(
              '현재 위치를 확인하는 중이에요...',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }
    final distance = _distanceMeters;
    if (distance != null) {
      return _infoCard(
        borderColor: AppColors.danger.withValues(alpha: 0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '퀘스트 장소에서 ${_formatDistance(distance)} 떨어져 있어요 '
              '(인증 반경 ${_radiusMeters}m)',
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '조금 더 가까이 이동한 뒤 다시 시도해주세요.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }
    final message = _statusMessage;
    if (message != null) {
      return _infoCard(
        borderColor: AppColors.danger.withValues(alpha: 0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (_showOpenSettings) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: Geolocator.openAppSettings,
                  child: const Text('설정 열기'),
                ),
              ),
            ],
          ],
        ),
      );
    }
    return _infoCard(
      child: const Text(
        'ℹ️ GPS 정확도에 따라 인증이 지연될 수 있습니다. 실외에서 시도해주세요.\n'
        '현재 위치는 거리 계산에만 사용되며 서버로 전송되지 않아요.',
        style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
      ),
    );
  }

  Widget _infoCard({required Widget child, Color? borderColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor ?? AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

/// QR 인증 — mobile_scanner로 현장 QR(`colortrip:quest:{id}:{서명16자}`)을 스캔해
/// 서버(`POST /verifications/qr`)가 서명을 검증한다. FE는 rawValue를 그대로 전달만 한다.
class _QrVerifyBody extends ConsumerStatefulWidget {
  const _QrVerifyBody({required this.quest, required this.onVerified});

  final Quest quest;
  final VoidCallback onVerified;

  @override
  ConsumerState<_QrVerifyBody> createState() => _QrVerifyBodyState();
}

class _QrVerifyBodyState extends ConsumerState<_QrVerifyBody> {
  late final MobileScannerController _controller;

  /// 스캔 프레임이 같은 QR을 연속 감지(onDetect 반복 호출)해도 검증 요청은
  /// 한 번만 나가도록 막는 플래그.
  bool _handling = false;

  /// 실패(거절·네트워크 오류) 후 "다시 스캔하기"를 누를 때까지 감지를 멈춘다 —
  /// 같은 QR을 계속 비추며 실패 요청이 무한 반복되는 것을 막는다.
  bool _awaitRescan = false;

  /// 카메라 시작 실패(권한·미지원 기기·테스트 환경 등) 여부.
  bool _cameraFailed = false;

  String? _failReason;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // autoStart를 끄고 직접 시작한다 — 시작 실패(카메라 없음 등)를 우리 UI로
    // 안내하기 위해서다. 컨트롤러를 직접 만들었으므로 dispose도 우리 몫이다.
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      autoStart: false,
    );
    unawaited(_startCamera());
  }

  Future<void> _startCamera() async {
    try {
      await _controller.start();
    } catch (_) {
      // MobileScannerException 계열은 컨트롤러가 삼켜 errorBuilder로 흐르고,
      // 그 외(테스트 환경의 MissingPluginException 등)는 여기로 온다.
      if (!mounted) return;
      setState(() => _cameraFailed = true);
    }
  }

  @override
  void dispose() {
    // 카메라 미지원 환경에선 정리 호출도 실패할 수 있어 에러를 무시한다.
    unawaited(_controller.dispose().catchError((_) {}));
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling || _awaitRescan) return;

    String? payload;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        payload = raw;
        break;
      }
    }
    if (payload == null) return;

    _handling = true;
    setState(() {
      _failReason = null;
      _errorMessage = null;
    });

    try {
      // 서명 검증은 서버가 한다 — 페이로드를 파싱하지 말고 그대로 보낸다.
      final verdict = await ref
          .read(verificationRepositoryProvider)
          .verifyQr(payload: payload, questId: widget.quest.id);
      if (!mounted) {
        _handling = false;
        return;
      }
      if (verdict.passed) {
        _handling = false;
        widget.onVerified();
        return;
      }
      setState(() {
        _handling = false;
        _awaitRescan = true;
        _failReason = verdict.reason.isEmpty
            ? '이 퀘스트의 QR이 아니에요.'
            : verdict.reason;
      });
    } on DioException {
      if (!mounted) {
        _handling = false;
        return;
      }
      setState(() {
        _handling = false;
        _awaitRescan = true;
        _errorMessage = '서버에 연결할 수 없어요. 잠시 후 다시 시도해주세요.';
      });
    } catch (_) {
      if (!mounted) {
        _handling = false;
        return;
      }
      setState(() {
        _handling = false;
        _awaitRescan = true;
        _errorMessage = 'QR 확인 중 문제가 발생했어요. 다시 시도해주세요.';
      });
    }
  }

  void _rescan() {
    setState(() {
      _awaitRescan = false;
      _failReason = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('QR 인증'),
        titleSpacing: 0,
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
            const SizedBox(height: 4),
            const Text(
              '현장에 부착된 QR 코드를 프레임 안에 맞춰주세요.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _cameraFailed
                    ? _scannerUnavailable()
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          MobileScanner(
                            controller: _controller,
                            fit: BoxFit.cover,
                            onDetect: _onDetect,
                            errorBuilder: (context, error) =>
                                _scannerUnavailable(),
                          ),
                          // 스캔 프레임 오버레이 — 시선을 중앙으로 모으는 가이드.
                          Center(
                            child: Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  width: 3,
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 14),
            _buildStatusPanel(),
          ],
        ),
      ),
    );
  }

  /// 카메라를 쓸 수 없을 때(권한 거부·미지원 기기·테스트 환경) 스캐너 자리 안내.
  Widget _scannerUnavailable() {
    return Container(
      color: AppColors.verifyMapBg,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: const Text(
        '카메라를 열 수 없어요.\n카메라 권한을 확인한 뒤 다시 들어와주세요.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5),
      ),
    );
  }

  Widget _buildStatusPanel() {
    if (_handling) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text(
            'QR을 확인하는 중이에요...',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      );
    }
    final message = _errorMessage ?? _failReason;
    if (message != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.danger,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: _rescan, child: const Text('다시 스캔하기')),
        ],
      );
    }
    return const Text(
      'QR이 인식되면 자동으로 인증이 진행돼요.',
      textAlign: TextAlign.center,
      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
    );
  }
}

class _PhotoVerifyBody extends ConsumerStatefulWidget {
  const _PhotoVerifyBody({required this.quest, required this.onVerified});

  final Quest quest;

  /// AI 판정 통과 시 완료 처리 콜백 — 사용자가 고른 사진(히스토리 보관용)과
  /// 실제 판정값(결과 화면 표시용)을 함께 넘긴다.
  final void Function(Uint8List photo, PhotoVerdict verdict) onVerified;

  @override
  ConsumerState<_PhotoVerifyBody> createState() => _PhotoVerifyBodyState();
}

class _PhotoVerifyBodyState extends ConsumerState<_PhotoVerifyBody> {
  // "업로드 가이드"에 안내한 상한과 맞춘다.
  static const _maxPhotoBytes = 5 * 1024 * 1024;

  Uint8List? _photoBytes;
  String _photoName = 'photo.jpg';

  /// AI 판정 요청 진행 중 여부(버튼 로딩 표시·중복 요청 방지).
  bool _verifying = false;

  /// 판정 거절(passed=false) 사유 — 배너로 보여주고 재선택을 허용한다.
  String? _failReason;

  /// 네트워크 등 요청 자체가 실패했을 때의 안내 문구(완료 처리 금지).
  String? _errorMessage;

  Future<void> _pickPhoto(ImageSource source) async {
    if (_verifying) return;
    final XFile? picked;
    try {
      // maxWidth/imageQuality로 대부분의 카메라 사진을 5MB 이하로 미리 줄인다.
      picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1920,
        imageQuality: 85,
      );
    } catch (_) {
      if (!mounted) return;
      showAppToast(context, '사진을 불러오지 못했어요. 카메라·사진 접근 권한을 확인해주세요.');
      return;
    }
    if (picked == null) return; // 사용자가 선택을 취소함 — 에러 아님.

    final Uint8List bytes;
    try {
      bytes = await picked.readAsBytes();
    } catch (_) {
      if (!mounted) return;
      showAppToast(context, '사진을 불러오지 못했어요. 다시 시도해주세요.');
      return;
    }
    if (bytes.length > _maxPhotoBytes) {
      if (!mounted) return;
      showAppToast(context, '사진 용량은 5MB 이하만 가능해요.');
      return;
    }

    if (!mounted) return;
    // 서버 multipart 파일명으로 쓴다 — 확장자가 MIME 판별 근거가 된다.
    final photoName = picked.name.isEmpty ? 'photo.jpg' : picked.name;
    setState(() {
      _photoBytes = bytes;
      _photoName = photoName;
      // 새 사진을 고르면 이전 판정 결과는 지운다(재시도 흐름).
      _failReason = null;
      _errorMessage = null;
    });
  }

  /// "사진으로 인증하기" — 서버 비전 모델 판정을 받고, 통과 시에만 완료 처리한다.
  Future<void> _verify() async {
    final bytes = _photoBytes;
    if (bytes == null || _verifying) return;

    setState(() {
      _verifying = true;
      _failReason = null;
      _errorMessage = null;
    });

    final PhotoVerdict verdict;
    try {
      verdict = await ref
          .read(verificationRepositoryProvider)
          .verifyPhoto(
            bytes: bytes,
            filename: _photoName,
            title: widget.quest.title,
            place: widget.quest.place,
            conditions: widget.quest.conditions,
          );
    } on DioException {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _errorMessage = '서버에 연결할 수 없어요. 잠시 후 다시 시도해주세요.';
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _errorMessage = '인증 처리 중 문제가 발생했어요. 다시 시도해주세요.';
      });
      return;
    }

    if (!mounted) return;
    if (verdict.passed) {
      setState(() => _verifying = false);
      widget.onVerified(bytes, verdict);
    } else {
      setState(() {
        _verifying = false;
        _failReason = verdict.reason.isEmpty
            ? '퀘스트 조건에 맞는 사진인지 확인해주세요.'
            : verdict.reason;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final photoBytes = _photoBytes;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('사진 인증'),
        titleSpacing: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                children: [
                  Text(
                    widget.quest.title,
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
                    onTap: _verifying
                        ? null
                        : () => _pickPhoto(ImageSource.gallery),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 120,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: AppColors.uploadBoxBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: photoBytes != null
                              ? AppColors.primaryDark
                              : AppColors.uploadBoxBorder,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: photoBytes != null
                          ? Image.memory(
                              photoBytes,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _PhotoSourceButton(
                          label: '📷 카메라',
                          onTap: _verifying
                              ? null
                              : () => _pickPhoto(ImageSource.camera),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PhotoSourceButton(
                          label: '🖼 갤러리',
                          onTap: _verifying
                              ? null
                              : () => _pickPhoto(ImageSource.gallery),
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
                  if (_failReason != null || _errorMessage != null) ...[
                    const SizedBox(height: 12),
                    _buildFailBanner(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: photoBytes != null && !_verifying ? _verify : null,
              child: _verifying
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Text('AI가 사진을 확인하고 있어요...'),
                      ],
                    )
                  : Text(photoBytes != null ? '사진으로 인증하기' : '사진 선택 후 인증 가능'),
            ),
          ],
        ),
      ),
    );
  }

  /// 판정 거절 사유 또는 네트워크 오류 안내 배너 — 사진 재선택으로 재시도한다.
  Widget _buildFailBanner() {
    final isNetworkError = _errorMessage != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isNetworkError ? _errorMessage! : 'AI 인증을 통과하지 못했어요',
            style: const TextStyle(
              color: AppColors.danger,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          if (!isNetworkError) ...[
            const SizedBox(height: 4),
            Text(
              _failReason!,
              style: const TextStyle(
                color: AppColors.textBody,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '다른 사진을 선택해 다시 시도해보세요.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoSourceButton extends StatelessWidget {
  const _PhotoSourceButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

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
