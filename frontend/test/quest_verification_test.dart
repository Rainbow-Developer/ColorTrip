/// KAN-58 퀘스트 인증 3종 — 인증 화면 분기(quiz 기존 동작 · gps 좌표 없음 안내 ·
/// qr 화면 렌더) 검증. 실제 측위·카메라·서버 호출은 위젯 테스트 범위 밖이라
/// 플랫폼 채널이 없는 환경에서도 안내 UI로 안전하게 내려앉는지를 본다.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:colortrip/core/config/app_config.dart';
import 'package:colortrip/core/network/dio_client.dart' show appConfigProvider;
import 'package:colortrip/data/location/location_gateway.dart';
import 'package:colortrip/data/media/photo_picker_gateway.dart';
import 'package:colortrip/data/models/quest.dart';
import 'package:colortrip/data/models/verification.dart';
import 'package:colortrip/data/repositories/domain_repository.dart';
import 'package:colortrip/data/repositories/quest_repository.dart';
import 'package:colortrip/data/static/quests_data.dart';
import 'package:colortrip/features/quests/gps_verify_map.dart';
import 'package:colortrip/features/quests/photo_verify_result_screen.dart';
import 'package:colortrip/features/quests/quest_verify_screen.dart';
import 'package:colortrip/state/progress_notifier.dart';
import 'package:colortrip/state/repository_providers.dart';

/// 정적 데이터의 보강(045: gps 퀘스트 좌표 추가·qr 전환)과 무관하게 분기를
/// 고정해서 테스트하기 위한 합성 퀘스트들.
const _gpsQuestWithoutCoords = Quest(
  id: 'test-gps',
  region: 'danyang',
  type: 'nature',
  title: '좌표 없는 GPS 퀘스트',
  place: '테스트 장소',
  verify: 'gps',
  reward: 10,
  desc: '',
  conditions: [],
);

/// 좌표가 있는 gps 퀘스트 — 도담삼봉 좌표(온디바이스 거리 판정 검증용).
const _gpsQuest = Quest(
  id: 'test-gps-coords',
  region: 'danyang',
  type: 'nature',
  title: '좌표 있는 GPS 퀘스트',
  place: '도담삼봉',
  verify: 'gps',
  reward: 10,
  desc: '',
  conditions: [],
  lat: 37.0008,
  lng: 128.3418,
  verifyRadius: 300,
);

/// 앱의 퀘스트 키(client_key)와 서버가 아는 UUID — 배경 지도 URL은 **UUID**를 써야 한다.
/// 앱 곳곳의 다른 API 호출과 같은 규칙이고, 이걸 빠뜨려 서버가 거절했던 게 KAN-91이다.
const _gpsQuestKey = 'test-gps-coords';
const _gpsQuestServerUuid = 'b1f0c2d3-4e5f-6789-abcd-ef0123456789';

/// 카탈로그에 서버 UUID 매핑이 없는 gps 퀘스트 — 배경 URL을 만들 수 없는 경우.
const _gpsQuestNotInCatalog = Quest(
  id: 'not-in-catalog',
  region: 'danyang',
  type: 'nature',
  title: '카탈로그에 없는 GPS 퀘스트',
  place: '도담삼봉',
  verify: 'gps',
  reward: 10,
  desc: '',
  conditions: [],
  lat: 37.0008,
  lng: 128.3418,
  verifyRadius: 300,
);

/// 측위를 대신하는 대역 — 플랫폼 채널 없이 임의 좌표를 돌려준다.
class _FakeLocationGateway implements LocationGateway {
  _FakeLocationGateway(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
  int calls = 0;

  @override
  Future<CurrentLocation> current() async {
    calls++;
    return CurrentLocation(latitude: latitude, longitude: longitude);
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

const _qrQuest = Quest(
  id: 'test-qr',
  region: 'danyang',
  type: 'history',
  title: 'QR 테스트 퀘스트',
  place: '테스트 장소',
  verify: 'qr',
  reward: 10,
  desc: '',
  conditions: [],
);

class _FakeQuestRepository implements QuestRepository {
  const _FakeQuestRepository(this.quests);

  final List<Quest> quests;

  @override
  List<Quest> all() => quests;

  @override
  Quest? byId(String id) {
    for (final q in quests) {
      if (q.id == id) return q;
    }
    return null;
  }

  @override
  List<Quest> byRegion(String regionId) =>
      quests.where((q) => q.region == regionId).toList();

  @override
  List<Quest> byType(String type) =>
      quests.where((q) => q.type == type).toList();
}

class _QuizDomainRepository implements DomainRepository {
  _QuizDomainRepository(this.expectedAnswer);

  final String expectedAnswer;
  final _completed = <String>{};

  @override
  Future<DomainSnapshot> fetchSnapshot() async => DomainSnapshot(
    catalog: const DomainCatalog(
      regionIdsByKey: {},
      regionKeysById: {},
      questIdsByKey: {_gpsQuestKey: _gpsQuestServerUuid},
      questKeysById: {_gpsQuestServerUuid: _gpsQuestKey},
    ),
    journeys: const [],
    completedQuestKeys: _completed,
    regionProgress: const {},
    regionTripCount: const {},
    timeline: const [],
  );

  @override
  Future<List<DomainRecommendedRegion>>
  fetchUnvisitedRecommendedRegions() async => const [];

  @override
  Future<List<String>> fetchRecommendedQuestKeys({
    String? category,
    required String regionKey,
    int size = 2,
  }) async => const [];

  @override
  Future<QuestVerification> verifyQuest({
    required String questKey,
    String? journeyId,
    String? photoUrl,
    String? answer,
    String? qrPayload,
  }) async {
    if (answer != expectedAnswer) {
      return const QuestVerification(verified: false);
    }
    _completed.add(questKey);
    return const QuestVerification(verified: true);
  }

  @override
  Future<DomainJourney> createJourney({
    required String clientRequestId,
    required String regionKey,
    required List<String> questKeys,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
  }) => throw UnimplementedError();

  @override
  Future<DomainJourney> replaceJourneyQuests({
    required String journeyId,
    required List<String> questKeys,
  }) => throw UnimplementedError();

  @override
  Future<DomainJourney> updateJourney({
    required String journeyId,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteJourney({required String journeyId}) =>
      throw UnimplementedError();

  @override
  Future<String> uploadPhoto(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
  }) => throw UnimplementedError();
}

/// 인증 화면은 완료 시 두 번 pop하므로(루트 ← 상세 ← 인증) 3단 스택으로 감싼다.
Widget _wrapVerifyScreen(String questId, ProviderContainer container) {
  final router = GoRouter(
    initialLocation: '/quest/$questId/verify',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('root')),
        routes: [
          GoRoute(
            path: 'quest/:id',
            builder: (_, _) => const Scaffold(body: Text('detail')),
            routes: [
              GoRoute(
                path: 'verify',
                builder: (context, state) =>
                    QuestVerifyScreen(questId: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'result',
                    builder: (context, state) => PhotoVerifyResultScreen(
                      questId: state.pathParameters['id']!,
                      verdict: state.extra is PhotoVerdict
                          ? state.extra as PhotoVerdict
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: 'region/:id',
            builder: (_, _) => const Scaffold(body: Text('region')),
          ),
        ],
      ),
    ],
  );
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
    ),
  );
}

ProviderContainer _container({
  List<Quest>? fakeQuests,
  DomainRepository? domainRepository,
  PhotoPickerGateway? photoPickerGateway,
  LocationGateway? locationGateway,
}) {
  final container = ProviderContainer(
    overrides: [
      // GPS 화면이 배경 지도 URL을 만들 때 읽는다(KAN-90). 실제 요청은 위젯 테스트에서
      // 실패하고 errorBuilder가 격자 도식으로 내려앉으므로 값 자체는 중요하지 않다.
      appConfigProvider.overrideWithValue(
        AppConfig.fromValues(
          kakaoNativeAppKey: 'test-key',
          apiBaseUrl: 'http://localhost:8000/api/v1',
        ),
      ),
      if (fakeQuests != null)
        questRepositoryProvider.overrideWith(
          (ref) => _FakeQuestRepository(fakeQuests),
        ),
      if (domainRepository != null)
        domainRepositoryProvider.overrideWithValue(domainRepository),
      if (photoPickerGateway != null)
        photoPickerGatewayProvider.overrideWithValue(photoPickerGateway),
      if (locationGateway != null)
        locationGatewayProvider.overrideWithValue(locationGateway),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// 1x1 투명 PNG — Image.memory 미리보기가 실제로 디코딩되는 최소 바이트.
final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/wcAAwAB/1e9AAAAAElFTkSuQmCC',
);

/// 플랫폼 채널 없이 사진 선택을 대체한다(gateway seam).
class _FakePhotoPickerGateway implements PhotoPickerGateway {
  @override
  Future<PickedPhotoFile?> pick(PhotoSource source) async => PickedPhotoFile(
    bytes: _pngBytes,
    filename: 'test.png',
    mimeType: 'image/png',
  );
}

/// 업로드·인증 호출을 기록하고, 서버처럼 verify 응답에 사진 판정을 담아주는 대역.
class _PhotoDomainRepository implements DomainRepository {
  _PhotoDomainRepository({
    this.verdict,
    this.verifyError,
    this.verifyGate,
    this.rejectWithoutVerdict = false,
  });

  /// 서버가 돌려줄 판정 상세 — null이면 사진 미션이 아닌 응답을 흉내 낸다.
  final PhotoVerdict? verdict;

  /// verify 호출 시 던질 오류(네트워크 실패 재현용).
  final Object? verifyError;

  /// 응답을 붙잡아 두는 게이트 — 요청 진행 중 UI를 검증할 때 쓴다.
  final Future<void>? verifyGate;

  /// 판정 상세 없이 거절하는 서버 응답(사진 미션이 아닌 사유로 거절되는 경우).
  final bool rejectWithoutVerdict;

  int uploadCalls = 0;
  int verifyCalls = 0;
  final _completed = <String>{};

  @override
  Future<DomainSnapshot> fetchSnapshot() async => DomainSnapshot(
    catalog: const DomainCatalog(
      regionIdsByKey: {},
      regionKeysById: {},
      questIdsByKey: {_gpsQuestKey: _gpsQuestServerUuid},
      questKeysById: {_gpsQuestServerUuid: _gpsQuestKey},
    ),
    journeys: const [],
    completedQuestKeys: _completed,
    regionProgress: const {},
    regionTripCount: const {},
    timeline: const [],
  );

  @override
  Future<String> uploadPhoto(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
  }) async {
    uploadCalls++;
    return '/uploads/photos/test.png';
  }

  @override
  Future<QuestVerification> verifyQuest({
    required String questKey,
    String? journeyId,
    String? photoUrl,
    String? answer,
    String? qrPayload,
  }) async {
    verifyCalls++;
    final gate = verifyGate;
    if (gate != null) await gate;
    final failure = verifyError;
    if (failure != null) throw failure;
    if (rejectWithoutVerdict) {
      return const QuestVerification(
        verified: false,
        reason: '업로드한 인증 사진이 필요합니다.',
      );
    }
    final judged = verdict;
    if (judged != null && !judged.passed) {
      return QuestVerification(
        verified: false,
        reason: judged.reason,
        photoVerdict: judged,
      );
    }
    _completed.add(questKey);
    return QuestVerification(verified: true, photoVerdict: judged);
  }

  @override
  Future<List<DomainRecommendedRegion>>
  fetchUnvisitedRecommendedRegions() async => const [];

  @override
  Future<List<String>> fetchRecommendedQuestKeys({
    String? category,
    required String regionKey,
    int size = 2,
  }) async => const [];

  @override
  Future<DomainJourney> createJourney({
    required String clientRequestId,
    required String regionKey,
    required List<String> questKeys,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
  }) => throw UnimplementedError();

  @override
  Future<DomainJourney> replaceJourneyQuests({
    required String journeyId,
    required List<String> questKeys,
  }) => throw UnimplementedError();

  @override
  Future<DomainJourney> updateJourney({
    required String journeyId,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteJourney({required String journeyId}) =>
      throw UnimplementedError();
}

void main() {
  testWidgets('quiz 분기 — 오답이면 안내, 정답이면 완료 처리 후 직전 화면으로 돌아간다', (tester) async {
    // OX 퀴즈는 이번 작업의 비변경 대상 — 정적 데이터의 실제 퀴즈 퀘스트로 검증한다
    // (completeQuest가 정적 데이터의 questById를 쓰므로 합성 퀘스트로는 완료가 안 된다).
    final quizQuest = kQuests.firstWhere((q) => q.verify == 'quiz');
    final container = _container(
      domainRepository: _QuizDomainRepository(
        quizQuest.quizAnswer! ? 'O' : 'X',
      ),
    );
    await tester.pumpWidget(_wrapVerifyScreen(quizQuest.id, container));
    await tester.pumpAndSettle();

    expect(find.text('OX 퀴즈'), findsOneWidget);
    expect(find.text(quizQuest.quizQuestion!), findsOneWidget);

    // 오답 → 완료되지 않고 재시도 안내.
    await tester.tap(find.text(quizQuest.quizAnswer! ? 'X' : 'O'));
    await tester.pump();
    expect(find.text('다시 생각해보세요.'), findsOneWidget);
    expect(container.read(progressProvider).isCompleted(quizQuest.id), isFalse);

    // 정답 → 완료 처리 후 인증 화면을 닫고 직전 화면으로 돌아간다(KAN-73 — go로 스택을
    // 교체하면 뒤로가기가 죽어 엉뚱한 화면에 남았다).
    await tester.tap(find.text(quizQuest.quizAnswer! ? 'O' : 'X'));
    await tester.pumpAndSettle();
    expect(container.read(progressProvider).isCompleted(quizQuest.id), isTrue);
    expect(find.text('퀘스트 완료! 지도가 칠해졌어요'), findsOneWidget);
    expect(find.text('OX 퀴즈'), findsNothing);
    expect(find.text('detail'), findsOneWidget);

    // 토스트 제거 타이머(1.9초)를 소진시켜 pending timer 실패를 막는다.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('gps 분기 — 좌표 없는 퀘스트는 준비 안 됨 안내를 띄우고 버튼을 비활성화한다', (tester) async {
    // 기본 테스트 화면(800x600)에서는 16:9 지도 박스 아래의 안내 카드가 ListView
    // 뷰포트를 벗어나 마운트되지 않는다 — 실제 단말처럼 세로로 긴 화면을 쓴다.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final container = _container(fakeQuests: [_gpsQuestWithoutCoords]);
    await tester.pumpWidget(
      _wrapVerifyScreen(_gpsQuestWithoutCoords.id, container),
    );
    await tester.pumpAndSettle();

    expect(find.text('GPS 인증'), findsOneWidget);
    expect(find.textContaining('이 퀘스트는 위치 정보가 준비되지 않았어요'), findsOneWidget);

    final button = find.widgetWithText(ElevatedButton, '현재 위치로 인증하기');
    expect(tester.widget<ElevatedButton>(button).enabled, isFalse);
  });

  testWidgets('qr 분기 — 카메라 없는 환경에서도 크래시 없이 렌더된다', (tester) async {
    // mobile_scanner 플랫폼 채널을 모킹한다 — 카메라 시작은 실패 처리하고,
    // 이벤트 채널 구독은 no-op으로 받아 FlutterError 리포트를 막는다.
    const methodChannel = MethodChannel(
      'dev.steenbakker.mobile_scanner/scanner/method',
    );
    const eventChannel = EventChannel(
      'dev.steenbakker.mobile_scanner/scanner/event',
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      methodChannel,
      (call) async => throw PlatformException(
        code: 'TEST_NO_CAMERA',
        message: '테스트 환경에는 카메라가 없다',
      ),
    );
    tester.binding.defaultBinaryMessenger.setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(onListen: (arguments, events) {}),
    );
    // 모킹 해제는 하지 않는다 — 테스트 종료 시 위젯 트리가 내려가며 컨트롤러
    // dispose가 플랫폼 채널을 다시 호출하는데, 그때도 모킹이 받아줘야 한다.

    final container = _container(fakeQuests: [_qrQuest]);
    await tester.pumpWidget(_wrapVerifyScreen(_qrQuest.id, container));
    // 카메라 시작 실패가 비동기로 반영되도록 몇 프레임 돌린다(pumpAndSettle은
    // 스캐너 내부 상태에 따라 오래 걸릴 수 있어 명시 pump 사용).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('QR 인증'), findsOneWidget);
    expect(find.text('현장에 부착된 QR 코드를 프레임 안에 맞춰주세요.'), findsOneWidget);

    // 스캐너 위젯이 살아 있거나(에러는 errorBuilder로 처리) 카메라 불가 안내로
    // 대체되었거나 — 어느 쪽이든 크래시 없이 렌더되면 통과.
    final hasScanner = find.byType(MobileScanner).evaluate().isNotEmpty;
    final hasFallback = find
        .textContaining('카메라를 열 수 없어요')
        .evaluate()
        .isNotEmpty;
    expect(hasScanner || hasFallback, isTrue);
  });

  group('photo 분기 — 서버 판정 결과로 완료·거절을 가른다 (050 · KAN-73)', () {
    /// 사진 인증 화면은 컨텐츠가 길어 기본 서피스(800x600)에서는 버튼이 잘린다.
    void useTallSurface(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
    }

    /// 사진을 고르고 "사진으로 인증하기"까지 누른다.
    Future<void> pickAndSubmit(WidgetTester tester) async {
      await tester.tap(find.text('🖼 갤러리'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('사진으로 인증하기'));
      await tester.pumpAndSettle();
    }

    testWidgets('판정을 통과하면 완료 처리하고 결과 화면에 판정값을 넘긴다', (tester) async {
      useTallSurface(tester);
      final photoQuest = kQuests.firstWhere((q) => q.verify == 'photo');
      final domain = _PhotoDomainRepository(
        verdict: const PhotoVerdict(
          passed: true,
          confidence: 0.87,
          reason: '도담삼봉 전경이 사진에서 확인됩니다.',
          provider: 'gemini',
        ),
      );
      final container = _container(
        domainRepository: domain,
        photoPickerGateway: _FakePhotoPickerGateway(),
      );
      await tester.pumpWidget(_wrapVerifyScreen(photoQuest.id, container));
      await tester.pumpAndSettle();

      await pickAndSubmit(tester);

      // 사진은 한 번만 올라가고(판정 전용 요청 없음), 인증도 한 번만 호출된다.
      expect(domain.uploadCalls, 1);
      expect(domain.verifyCalls, 1);
      // 결과 화면이 라우트 extra로 서버 판정값을 받아 표시한다.
      expect(find.text('사진 검증 결과'), findsOneWidget);
      expect(find.text('인증 성공!'), findsOneWidget);
      expect(find.text('87%'), findsOneWidget);
      expect(find.text('도담삼봉 전경이 사진에서 확인됩니다.'), findsOneWidget);
      expect(find.text('AI 미설정(스텁 판정)'), findsNothing);
    });

    testWidgets('스텁 판정이면 결과 화면에 "AI 미설정" 뱃지를 띄운다', (tester) async {
      useTallSurface(tester);
      final photoQuest = kQuests.firstWhere((q) => q.verify == 'photo');
      final container = _container(
        domainRepository: _PhotoDomainRepository(
          verdict: const PhotoVerdict(
            passed: true,
            confidence: 0,
            reason: 'AI 미설정 — 스텁 판정으로 통과 처리했습니다.',
            provider: 'stub',
          ),
        ),
        photoPickerGateway: _FakePhotoPickerGateway(),
      );
      await tester.pumpWidget(_wrapVerifyScreen(photoQuest.id, container));
      await tester.pumpAndSettle();

      await pickAndSubmit(tester);

      expect(find.text('AI 미설정(스텁 판정)'), findsOneWidget);
    });

    testWidgets('판정이 거절하면 완료되지 않고 사유를 화면에 남긴다', (tester) async {
      useTallSurface(tester);
      final photoQuest = kQuests.firstWhere((q) => q.verify == 'photo');
      final domain = _PhotoDomainRepository(
        verdict: const PhotoVerdict(
          passed: false,
          confidence: 0.12,
          reason: '사진에서 퀘스트 장소를 확인할 수 없습니다.',
          provider: 'gemini',
        ),
      );
      final container = _container(
        domainRepository: domain,
        photoPickerGateway: _FakePhotoPickerGateway(),
      );
      await tester.pumpWidget(_wrapVerifyScreen(photoQuest.id, container));
      await tester.pumpAndSettle();

      await pickAndSubmit(tester);

      expect(
        container.read(progressProvider).isCompleted(photoQuest.id),
        isFalse,
      );
      // 인증 화면에 머무르며 판정 사유를 보여준다(재시도 가능).
      expect(find.text('사진 인증'), findsOneWidget);
      expect(find.text('사진에서 퀘스트 장소를 확인할 수 없습니다.'), findsOneWidget);
      expect(find.text('사진 검증 결과'), findsNothing);
    });

    testWidgets('인증 요청이 실패하면 완료되지 않고 재시도를 안내한다', (tester) async {
      useTallSurface(tester);
      final photoQuest = kQuests.firstWhere((q) => q.verify == 'photo');
      final container = _container(
        domainRepository: _PhotoDomainRepository(
          verifyError: Exception('network down'),
        ),
        photoPickerGateway: _FakePhotoPickerGateway(),
      );
      await tester.pumpWidget(_wrapVerifyScreen(photoQuest.id, container));
      await tester.pumpAndSettle();

      await pickAndSubmit(tester);

      expect(
        container.read(progressProvider).isCompleted(photoQuest.id),
        isFalse,
      );
      expect(find.textContaining('다시 시도해주세요'), findsOneWidget);
    });

    testWidgets('확인 중에는 뒤로가기로 화면을 벗어날 수 없다', (tester) async {
      // 스크림으로 조작을 막아도 뒤로가기가 열려 있으면, 서버 인증은 진행됐는데
      // 결과 화면을 못 보고 나가게 된다(PopScope + leading 비활성의 의도).
      useTallSurface(tester);
      final photoQuest = kQuests.firstWhere((q) => q.verify == 'photo');
      final gate = Completer<void>();
      final container = _container(
        domainRepository: _PhotoDomainRepository(
          verdict: const PhotoVerdict(
            passed: true,
            confidence: 0.9,
            reason: '통과',
            provider: 'gemini',
          ),
          verifyGate: gate.future,
        ),
        photoPickerGateway: _FakePhotoPickerGateway(),
      );
      await tester.pumpWidget(_wrapVerifyScreen(photoQuest.id, container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('🖼 갤러리'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('사진으로 인증하기'));
      await tester.pump(); // 요청 진행 중(스크림 표시)

      expect(find.text('사진 확인 중...'), findsWidgets);
      // 시스템 뒤로가기를 시도해도 화면이 유지된다.
      final popped = await tester.binding.handlePopRoute();
      await tester.pump();
      expect(popped, isTrue); // 라우터가 처리했지만 PopScope가 막았다
      expect(find.text('사진 인증'), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('사진 검증 결과'), findsOneWidget);
    });

    testWidgets('판정값이 없는 거절 응답은 서버 reason으로 안내한다', (tester) async {
      useTallSurface(tester);
      final photoQuest = kQuests.firstWhere((q) => q.verify == 'photo');
      final container = _container(
        domainRepository: _PhotoDomainRepository(rejectWithoutVerdict: true),
        photoPickerGateway: _FakePhotoPickerGateway(),
      );
      await tester.pumpWidget(_wrapVerifyScreen(photoQuest.id, container));
      await tester.pumpAndSettle();

      await pickAndSubmit(tester);

      expect(find.text('업로드한 인증 사진이 필요합니다.'), findsOneWidget);
      expect(find.text('사진 검증 결과'), findsNothing);
    });

    testWidgets('사진을 다시 고르면 지난 판정 사유가 사라진다', (tester) async {
      useTallSurface(tester);
      final photoQuest = kQuests.firstWhere((q) => q.verify == 'photo');
      final container = _container(
        domainRepository: _PhotoDomainRepository(
          verdict: const PhotoVerdict(
            passed: false,
            confidence: 0.1,
            reason: '사진에서 퀘스트 장소를 확인할 수 없습니다.',
            provider: 'gemini',
          ),
        ),
        photoPickerGateway: _FakePhotoPickerGateway(),
      );
      await tester.pumpWidget(_wrapVerifyScreen(photoQuest.id, container));
      await tester.pumpAndSettle();

      await pickAndSubmit(tester);
      expect(find.text('사진에서 퀘스트 장소를 확인할 수 없습니다.'), findsOneWidget);

      // 새 사진을 고르면 지난 판정 사유는 지운다(현재 사진과 무관한 안내가 남지 않게).
      await tester.tap(find.text('📷 카메라'));
      await tester.pumpAndSettle();
      expect(find.text('사진에서 퀘스트 장소를 확인할 수 없습니다.'), findsNothing);
    });
  });

  testWidgets('gps 분기 — 반경 밖이면 서버를 부르지 않고 거리만 안내한다', (tester) async {
    // 위치 판정은 단말에서 끝난다(KAN-77). 반경 밖에서 서버를 부르면 좌표가 필요해지고,
    // 좌표를 보내는 순간 위치정보법상 신고 대상이 된다(location-law-review.md).
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final repository = _PhotoDomainRepository();
    // 도담삼봉에서 약 1.4km 떨어진 좌표(반경 300m 밖).
    final gateway = _FakeLocationGateway(37.0130, 128.3418);
    final container = _container(
      fakeQuests: [_gpsQuest],
      domainRepository: repository,
      locationGateway: gateway,
    );
    await tester.pumpWidget(_wrapVerifyScreen(_gpsQuest.id, container));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, '현재 위치로 인증하기'));
    await tester.pumpAndSettle();

    // 측위 횟수는 단언하지 않는다 — 도식 표시를 위해 화면 진입 시에도 측위하므로(KAN-87)
    // 횟수는 구현에 따라 달라진다. 이 테스트의 불변식은 **서버를 부르지 않는 것**이다.
    expect(gateway.calls, greaterThan(0));
    expect(repository.verifyCalls, 0); // 서버 호출 없음
    // 도식 칩과 토스트가 같은 문구를 갖게 되어 매칭이 여럿이다(KAN-87).
    expect(find.textContaining('떨어져 있어요'), findsWidgets);
    expect(find.textContaining('인증 반경 300m'), findsWidgets);

    await tester.pump(const Duration(seconds: 2)); // 토스트 타이머 소진
  });

  testWidgets('gps 분기 — 반경 이내면 좌표 없이 인증을 요청한다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final repository = _PhotoDomainRepository();
    // 퀘스트 좌표에서 약 20m 거리(반경 300m 이내).
    final gateway = _FakeLocationGateway(37.00098, 128.3418);
    final container = _container(
      fakeQuests: [_gpsQuest],
      domainRepository: repository,
      locationGateway: gateway,
    );
    await tester.pumpWidget(_wrapVerifyScreen(_gpsQuest.id, container));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, '현재 위치로 인증하기'));
    await tester.pumpAndSettle();

    expect(repository.verifyCalls, 1);
    expect(find.text('퀘스트 완료! 지도가 칠해졌어요'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
  });

  test('distanceMeters는 하버사인 거리를 계산한다', () {
    // 같은 지점은 0, 위도 1도 차이는 약 111km.
    expect(distanceMeters(37.0, 128.0, 37.0, 128.0), 0);
    expect(distanceMeters(37.0, 128.0, 38.0, 128.0), closeTo(111195, 500));
    // 도담삼봉 기준 약 20m 떨어진 좌표.
    expect(
      distanceMeters(37.0008, 128.3418, 37.00098, 128.3418),
      closeTo(20, 3),
    );
  });

  // --- KAN-87 위치 도식 -------------------------------------------------

  test('questRelativeOffsetMeters는 퀘스트 기준 동/북 오프셋(m)을 준다', () {
    // 같은 지점이면 원점.
    expect(
      questRelativeOffsetMeters(
        questLat: 37.0,
        questLng: 128.0,
        myLat: 37.0,
        myLng: 128.0,
      ),
      Offset.zero,
    );

    // 북쪽으로 0.001도 ≈ 111m. 동쪽 성분은 0.
    final north = questRelativeOffsetMeters(
      questLat: 37.0,
      questLng: 128.0,
      myLat: 37.001,
      myLng: 128.0,
    );
    expect(north.dx, closeTo(0, 0.001));
    expect(north.dy, closeTo(111, 1));

    // 동쪽으로 0.001도는 위도 37도에서 약 89m(cos 37° ≈ 0.7986)로 줄어든다.
    final east = questRelativeOffsetMeters(
      questLat: 37.0,
      questLng: 128.0,
      myLat: 37.0,
      myLng: 128.001,
    );
    expect(east.dx, closeTo(89, 1));
    expect(east.dy, closeTo(0, 0.001));

    // 남서쪽은 두 성분 모두 음수 — 방향이 뒤집히지 않는지 확인한다.
    final southWest = questRelativeOffsetMeters(
      questLat: 37.0,
      questLng: 128.0,
      myLat: 36.999,
      myLng: 127.999,
    );
    expect(southWest.dx, lessThan(0));
    expect(southWest.dy, lessThan(0));
  });

  test('metersPerPixel은 VWorld 실측 축척과 일치한다', () {
    // 2026-08-15 실측: VWorld 이미지 API(zoom 15)에서 center를 256px에 해당하는 경도만큼
    // 옮긴 이미지가 원본의 오른쪽 절반과 픽셀 단위로 일치했다(워터마크 영역 제외).
    // 그때 쓴 값이 3.8153m/px이고, 이 함수가 같은 값을 내야 오버레이가 지도와 정렬된다.
    expect(metersPerPixel(latitude: 37.0008, zoom: 15), closeTo(3.8153, 0.001));
    // 줌이 1 오르면 축척은 정확히 절반이다.
    expect(
      metersPerPixel(latitude: 37.0008, zoom: 16),
      closeTo(metersPerPixel(latitude: 37.0008, zoom: 15) / 2, 1e-9),
    );
    // 적도에서 가장 크고 고위도로 갈수록 줄어든다.
    expect(
      metersPerPixel(latitude: 0, zoom: 15),
      greaterThan(metersPerPixel(latitude: 60, zoom: 15)),
    );
  });

  test('mapImageSpanMeters는 배경 지도가 담는 가로 거리를 준다', () {
    // 640px × 3.8153m/px ≈ 2441.8m. 인증 반경 500m(지름 1km)가 넉넉히 들어온다.
    final span = mapImageSpanMeters(latitude: 37.0008);
    expect(span, closeTo(2441.8, 1.0));
    expect(span, greaterThan(1000)); // 기본 반경의 지름보다 넓어야 한다
  });

  test('mapSpanMeters는 반경과 내 위치가 모두 담기도록 정해진다', () {
    // 내 위치를 모르면 반경만 여유 있게 담는다.
    expect(mapSpanMeters(radiusMeters: 500), closeTo(675, 0.1));
    // 반경 안이면 여전히 반경 기준(내 거리에 맞춰 과하게 확대하지 않는다).
    expect(
      mapSpanMeters(radiusMeters: 500, distanceMeters: 100),
      closeTo(675, 0.1),
    );
    // 반경 밖이면 그 거리까지 담는다.
    expect(
      mapSpanMeters(radiusMeters: 500, distanceMeters: 2000),
      closeTo(2500, 0.1),
    );
  });

  testWidgets('gps 분기 — 화면에 들어가면 인증 전에 측위해 도식에 거리를 표시한다', (tester) async {
    // KAN-87: 인증을 눌러야 측위하던 이전 방식으로는 어느 쪽으로 얼마나 가야 하는지
    // 인증 전에 알 수 없었다.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final repository = _PhotoDomainRepository();
    // 도담삼봉에서 약 1.4km 떨어진 좌표(반경 300m 밖).
    final gateway = _FakeLocationGateway(37.0130, 128.3418);
    final container = _container(
      fakeQuests: [_gpsQuest],
      domainRepository: repository,
      locationGateway: gateway,
    );
    await tester.pumpWidget(_wrapVerifyScreen(_gpsQuest.id, container));
    await tester.pumpAndSettle();

    // 버튼을 누르지 않았는데도 측위가 끝나 있고, 서버는 부르지 않았다.
    expect(gateway.calls, 1);
    expect(repository.verifyCalls, 0);
    expect(find.byType(GpsVerifyMap), findsOneWidget);
    expect(find.textContaining('떨어져'), findsWidgets);
  });

  testWidgets('gps 분기 — 배경 지도 URL은 client_key가 아니라 서버 UUID를 쓴다', (
    tester,
  ) async {
    // KAN-91: 앱의 quest.id는 client_key(`dy3`)인데 서버 경로는 UUID를 받는다. 카탈로그
    // 변환을 빠뜨리면 서버가 거절하고 배경이 통째로 사라진다(사용자 보고 "지도가 전혀 안 뜬다").
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final container = _container(
      fakeQuests: [_gpsQuest],
      domainRepository: _PhotoDomainRepository(),
      locationGateway: _FakeLocationGateway(37.0130, 128.3418),
    );
    await tester.pumpWidget(_wrapVerifyScreen(_gpsQuest.id, container));
    await tester.pumpAndSettle();

    final map = tester.widget<GpsVerifyMap>(find.byType(GpsVerifyMap));
    expect(map.mapImageUrl, isNotNull);
    expect(map.mapImageUrl, contains(_gpsQuestServerUuid));
    expect(
      map.mapImageUrl,
      isNot(contains(_gpsQuestKey)),
      reason: 'client_key를 그대로 넣으면 서버가 UUID 파싱에 실패한다',
    );
  });

  testWidgets('gps 분기 — 카탈로그에 없는 퀘스트는 배경 없이 그린다', (tester) async {
    // 카탈로그가 아직 없거나 서버에 없는 퀘스트면 URL을 만들 수 없다. 배경은 참고용이라
    // 없으면 도식만 그리면 되고, 인증을 막아서는 안 된다.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final container = _container(
      fakeQuests: [_gpsQuestNotInCatalog],
      domainRepository: _PhotoDomainRepository(),
      locationGateway: _FakeLocationGateway(37.0130, 128.3418),
    );
    await tester.pumpWidget(
      _wrapVerifyScreen(_gpsQuestNotInCatalog.id, container),
    );
    await tester.pumpAndSettle();

    final map = tester.widget<GpsVerifyMap>(find.byType(GpsVerifyMap));
    expect(map.mapImageUrl, isNull);
    expect(find.widgetWithText(ElevatedButton, '현재 위치로 인증하기'), findsOneWidget);
  });

  testWidgets('gps 분기 — 측위에 실패해도 도식은 그리고 화면을 막지 않는다', (tester) async {
    // 권한 거부·서비스 꺼짐의 사유별 안내는 실제 인증 시도가 담당한다. 진입 시 측위는
    // 조용히 실패하고 퀘스트 지점·반경만 그린다.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final container = _container(
      fakeQuests: [_gpsQuest],
      domainRepository: _PhotoDomainRepository(),
      locationGateway: _FailingLocationGateway(),
    );
    await tester.pumpWidget(_wrapVerifyScreen(_gpsQuest.id, container));
    await tester.pumpAndSettle();

    expect(find.byType(GpsVerifyMap), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '현재 위치로 인증하기'), findsOneWidget);
  });
}

/// 측위가 항상 실패하는 게이트웨이 — 진입 시 자동 측위의 실패 경로 검증용.
class _FailingLocationGateway implements LocationGateway {
  @override
  Future<CurrentLocation> current() async =>
      throw const LocationFailure(LocationFailureReason.permissionDenied);

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}
