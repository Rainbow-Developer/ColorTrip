import 'dart:convert';
import 'dart:typed_data';

import 'package:colortrip/data/auth/kakao_auth_gateway.dart';
import 'package:colortrip/data/auth/secure_token_storage.dart';
import 'package:colortrip/data/models/auth_models.dart';
import 'package:colortrip/data/repositories/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Gateway implements KakaoAuthGateway {
  int loginCalls = 0;
  int logoutCalls = 0;
  int unlinkCalls = 0;
  Future<void> Function()? onUnlink;

  @override
  Future<String> login() async {
    loginCalls++;
    return 'kakao-access';
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
  }

  @override
  Future<void> unlink() async {
    unlinkCalls++;
    await onUnlink?.call();
  }
}

class _Storage implements SecureTokenStorage {
  TokenPair? tokens;
  int clears = 0;
  WithdrawalStage stage = WithdrawalStage.none;

  bool get withdrawalPending => stage != WithdrawalStage.none;
  set withdrawalPending(bool value) {
    stage = value ? WithdrawalStage.backendPending : WithdrawalStage.none;
  }

  @override
  Future<void> clear() async {
    clears++;
    tokens = null;
    stage = WithdrawalStage.none;
  }

  @override
  Future<bool> clearIfRefreshToken(String expectedRefreshToken) async {
    if (tokens?.refreshToken != expectedRefreshToken) return false;
    await clear();
    return true;
  }

  @override
  Future<bool> isWithdrawalPending() async => stage != WithdrawalStage.none;

  @override
  Future<void> markWithdrawalPending() async {
    stage = WithdrawalStage.backendPending;
  }

  @override
  Future<void> markWithdrawalUnlinkPending() async {
    stage = WithdrawalStage.unlinkPending;
  }

  @override
  Future<TokenPair?> read() async => tokens;

  @override
  Future<void> replace(
    TokenPair tokens, {
    bool preserveWithdrawalState = true,
  }) async {
    this.tokens = tokens;
    if (!preserveWithdrawalState) stage = WithdrawalStage.none;
  }

  @override
  Future<bool> replaceIfRefreshToken(
    String expectedRefreshToken,
    TokenPair tokens,
  ) async {
    if (this.tokens?.refreshToken != expectedRefreshToken) return false;
    await replace(tokens);
    return true;
  }

  @override
  Future<WithdrawalStage> withdrawalStage() async => stage;
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _response(int status, Map<String, dynamic> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

Map<String, dynamic> get _profile => {
  'id': '018f0000-0000-7000-8000-000000000001',
  'nickname': '컬러트립',
  'birth_date': '2000-01-02',
  'profile_image': null,
  'dna': null,
  'social_provider': 'kakao',
  'onboarding_step': 'trip_dna',
  'is_restored': false,
};

void main() {
  test(
    'login exchanges only Kakao access token and stores ColorTrip JWTs',
    () async {
      final gateway = _Gateway();
      final storage = _Storage();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      late Map<String, dynamic> requestBody;
      dio.httpClientAdapter = _Adapter((options) async {
        requestBody = Map<String, dynamic>.from(options.data as Map);
        return _response(200, {
          'data': {
            'access_token': 'colortrip-access',
            'refresh_token': 'colortrip-refresh',
            'token_type': 'bearer',
            'is_restored': false,
            'user': _profile,
          },
        });
      });
      final repository = DioAuthRepository(
        dio: dio,
        kakao: gateway,
        storage: storage,
      );

      final session = await repository.loginWithKakao();

      expect(requestBody, {
        'provider': 'kakao',
        'access_token': 'kakao-access',
      });
      expect(session.user.onboardingStep, OnboardingStep.tripDna);
      expect(storage.tokens!.accessToken, 'colortrip-access');
      expect(storage.tokens!.refreshToken, 'colortrip-refresh');
    },
  );

  test('a successful login starts a fresh non-withdrawal session', () async {
    final gateway = _Gateway();
    final storage = _Storage()
      ..tokens = const TokenPair(
        accessToken: 'withdrawal-access',
        refreshToken: 'withdrawal-refresh',
      )
      ..stage = WithdrawalStage.backendPending;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    dio.httpClientAdapter = _Adapter((options) async {
      return _response(200, {
        'data': {
          'access_token': 'new-access',
          'refresh_token': 'new-refresh',
          'token_type': 'bearer',
          'is_restored': false,
          'user': _profile,
        },
      });
    });
    final repository = DioAuthRepository(
      dio: dio,
      kakao: gateway,
      storage: storage,
    );

    await repository.loginWithKakao();

    expect(storage.stage, WithdrawalStage.none);
  });

  test('onboarding profile uses the exact flat backend contract', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    late RequestOptions request;
    dio.httpClientAdapter = _Adapter((options) async {
      request = options;
      return _response(200, {'data': _profile});
    });
    final repository = DioAuthRepository(
      dio: dio,
      kakao: _Gateway(),
      storage: _Storage(),
    );

    await repository.submitOnboardingProfile(
      OnboardingProfileInput(
        nickname: ' 컬러트립 ',
        birthDate: DateTime(2000, 1, 2),
        termsAgreed: true,
        privacyAgreed: true,
      ),
    );

    expect(request.path, '/users/me/onboarding-profile');
    expect(request.method, 'PUT');
    expect(Map<String, dynamic>.from(request.data as Map), {
      'nickname': '컬러트립',
      'birth_date': '2000-01-02',
      'terms_agreed': true,
      'privacy_agreed': true,
    });
  });

  test(
    'logout always clears local tokens when both remote calls fail',
    () async {
      final gateway = _FailingGateway();
      final storage = _Storage()
        ..tokens = const TokenPair(
          accessToken: 'access',
          refreshToken: 'refresh',
        );
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      var revokeAttempts = 0;
      dio.httpClientAdapter = _Adapter((options) async {
        revokeAttempts++;
        return _response(503, {'code': 'TEMPORARY_FAILURE'});
      });
      final repository = DioAuthRepository(
        dio: dio,
        kakao: gateway,
        storage: storage,
        logoutAttempts: 2,
      );

      await repository.logout();

      expect(revokeAttempts, 2);
      expect(gateway.logoutCalls, 1);
      expect(storage.tokens, isNull);
      expect(storage.clears, 1);
    },
  );

  test(
    'logout retries with the refresh token rotated by a 401 handler',
    () async {
      final gateway = _Gateway();
      final storage = _Storage()
        ..tokens = const TokenPair(
          accessToken: 'old-access',
          refreshToken: 'old-refresh',
        );
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      final submittedRefreshTokens = <String>[];
      dio.httpClientAdapter = _Adapter((options) async {
        final body = Map<String, dynamic>.from(options.data as Map);
        submittedRefreshTokens.add(body['refresh_token'] as String);
        if (submittedRefreshTokens.length == 1) {
          await storage.replace(
            const TokenPair(
              accessToken: 'new-access',
              refreshToken: 'new-refresh',
            ),
          );
          return _response(401, {'code': 'TOKEN_EXPIRED'});
        }
        return _response(204, const {});
      });
      final repository = DioAuthRepository(
        dio: dio,
        kakao: gateway,
        storage: storage,
        logoutAttempts: 2,
      );

      await repository.logout();

      expect(submittedRefreshTokens, ['old-refresh', 'new-refresh']);
    },
  );

  test(
    'withdrawal keeps JWTs when backend delete fails after unlink',
    () async {
      final gateway = _Gateway();
      final storage = _Storage()
        ..tokens = const TokenPair(
          accessToken: 'access',
          refreshToken: 'refresh',
        );
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      dio.httpClientAdapter = _Adapter(
        (options) async => _response(503, {'code': 'TEMPORARY_FAILURE'}),
      );
      final repository = DioAuthRepository(
        dio: dio,
        kakao: gateway,
        storage: storage,
      );

      await expectLater(repository.withdraw(), throwsA(isA<DioException>()));

      expect(gateway.unlinkCalls, 1);
      expect(storage.tokens, isNotNull);
      expect(storage.clears, 0);
      expect(storage.withdrawalPending, isTrue);
    },
  );

  test('persists unlink intent before calling the Kakao SDK', () async {
    final gateway = _Gateway();
    final storage = _Storage()
      ..tokens = const TokenPair(
        accessToken: 'access',
        refreshToken: 'refresh',
      );
    gateway.onUnlink = () async {
      expect(storage.stage, WithdrawalStage.unlinkPending);
    };
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    dio.httpClientAdapter = _Adapter(
      (options) async => _response(503, {'code': 'TEMPORARY_FAILURE'}),
    );
    final repository = DioAuthRepository(
      dio: dio,
      kakao: gateway,
      storage: storage,
    );

    await expectLater(repository.withdraw(), throwsA(isA<DioException>()));

    expect(storage.stage, WithdrawalStage.backendPending);
  });

  test(
    'retries Kakao unlink after a crash-safe unlink-pending marker',
    () async {
      final gateway = _FailingUnlinkOnceGateway();
      final storage = _Storage()
        ..tokens = const TokenPair(
          accessToken: 'access',
          refreshToken: 'refresh',
        );
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      dio.httpClientAdapter = _Adapter(
        (options) async => _response(204, const {}),
      );
      final repository = DioAuthRepository(
        dio: dio,
        kakao: gateway,
        storage: storage,
      );

      await expectLater(repository.withdraw(), throwsA(isA<StateError>()));
      expect(storage.stage, WithdrawalStage.unlinkPending);

      await repository.withdraw();

      expect(gateway.unlinkCalls, 2);
      expect(storage.tokens, isNull);
    },
  );

  test('withdrawal retry skips duplicate unlink after app restart', () async {
    final gateway = _Gateway();
    final storage = _Storage()
      ..tokens = const TokenPair(accessToken: 'access', refreshToken: 'refresh')
      ..withdrawalPending = true;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    dio.httpClientAdapter = _Adapter(
      (options) async => _response(204, const {}),
    );
    final repository = DioAuthRepository(
      dio: dio,
      kakao: gateway,
      storage: storage,
    );

    await repository.withdraw();

    expect(gateway.unlinkCalls, 0);
    expect(storage.tokens, isNull);
  });

  test('restoreSession surfaces transient API failures for retry UI', () async {
    final storage = _Storage()
      ..tokens = const TokenPair(
        accessToken: 'access',
        refreshToken: 'refresh',
      );
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    dio.httpClientAdapter = _Adapter(
      (options) async => _response(503, {'code': 'TEMPORARY_FAILURE'}),
    );
    final repository = DioAuthRepository(
      dio: dio,
      kakao: _Gateway(),
      storage: storage,
    );

    await expectLater(
      repository.restoreSession(),
      throwsA(isA<DioException>()),
    );
    expect(storage.tokens, isNotNull);
  });

  test('uploads a profile image with the picker-provided MIME type', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    late RequestOptions request;
    dio.httpClientAdapter = _Adapter((options) async {
      request = options;
      return _response(200, {
        'data': {
          ..._profile,
          'profile_image': '/uploads/avatars/2026/08/a.png',
        },
      });
    });
    final repository = DioAuthRepository(
      dio: dio,
      kakao: _Gateway(),
      storage: _Storage(),
    );

    final user = await repository.uploadProfileImage(
      Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]),
      mimeType: 'image/png',
    );

    expect(request.path, '/users/me/profile-image');
    expect(request.method, 'POST');
    final form = request.data as FormData;
    expect(form.files.single.key, 'file');
    expect(form.files.single.value.filename, 'profile.png');
    expect(form.files.single.value.contentType.toString(), 'image/png');
    expect(user.profileImage, '/uploads/avatars/2026/08/a.png');
  });

  test('removes a profile image and returns the cleared profile', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    late RequestOptions request;
    dio.httpClientAdapter = _Adapter((options) async {
      request = options;
      return _response(200, {
        'data': {..._profile, 'profile_image': null},
      });
    });
    final repository = DioAuthRepository(
      dio: dio,
      kakao: _Gateway(),
      storage: _Storage(),
    );

    final user = await repository.removeProfileImage();

    expect(request.path, '/users/me/profile-image');
    expect(request.method, 'DELETE');
    expect(user.profileImage, isNull);
  });
}

class _FailingGateway extends _Gateway {
  @override
  Future<void> logout() async {
    logoutCalls++;
    throw StateError('Kakao unavailable');
  }
}

class _FailingUnlinkOnceGateway extends _Gateway {
  bool _failed = false;

  @override
  Future<void> unlink() async {
    unlinkCalls++;
    if (!_failed) {
      _failed = true;
      throw StateError('Kakao temporarily unavailable');
    }
  }
}
