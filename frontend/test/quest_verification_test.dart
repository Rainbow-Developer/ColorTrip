/// KAN-58 퀘스트 인증 3종 — 인증 화면 분기(quiz 기존 동작 · gps 좌표 없음 안내 ·
/// qr 화면 렌더) 검증. 실제 측위·카메라·서버 호출은 위젯 테스트 범위 밖이라
/// 플랫폼 채널이 없는 환경에서도 안내 UI로 안전하게 내려앉는지를 본다.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:colortrip/data/media/photo_picker_gateway.dart';
import 'package:colortrip/data/models/quest.dart';
import 'package:colortrip/data/models/verification.dart';
import 'package:colortrip/data/repositories/domain_repository.dart';
import 'package:colortrip/data/repositories/quest_repository.dart';
import 'package:colortrip/data/static/quests_data.dart';
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
      questIdsByKey: {},
      questKeysById: {},
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
    required String regionKey,
    int size = 2,
  }) async => const [];

  @override
  Future<QuestVerification> verifyQuest({
    required String questKey,
    String? journeyId,
    double? latitude,
    double? longitude,
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
}) {
  final container = ProviderContainer(
    overrides: [
      if (fakeQuests != null)
        questRepositoryProvider.overrideWith(
          (ref) => _FakeQuestRepository(fakeQuests),
        ),
      if (domainRepository != null)
        domainRepositoryProvider.overrideWithValue(domainRepository),
      if (photoPickerGateway != null)
        photoPickerGatewayProvider.overrideWithValue(photoPickerGateway),
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
  _PhotoDomainRepository({this.verdict, this.verifyError});

  /// 서버가 돌려줄 판정 상세 — null이면 사진 미션이 아닌 응답을 흉내 낸다.
  final PhotoVerdict? verdict;

  /// verify 호출 시 던질 오류(네트워크 실패 재현용).
  final Object? verifyError;

  int uploadCalls = 0;
  int verifyCalls = 0;
  final _completed = <String>{};

  @override
  Future<DomainSnapshot> fetchSnapshot() async => DomainSnapshot(
    catalog: const DomainCatalog(
      regionIdsByKey: {},
      regionKeysById: {},
      questIdsByKey: {},
      questKeysById: {},
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
    double? latitude,
    double? longitude,
    String? photoUrl,
    String? answer,
    String? qrPayload,
  }) async {
    verifyCalls++;
    final failure = verifyError;
    if (failure != null) throw failure;
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
  });
}
