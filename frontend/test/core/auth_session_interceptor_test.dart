import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:colortrip/core/network/auth_session_interceptor.dart';
import 'package:colortrip/data/auth/secure_token_storage.dart';
import 'package:colortrip/data/models/auth_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryTokenStorage implements SecureTokenStorage {
  _MemoryTokenStorage(this.tokens);

  TokenPair? tokens;
  int replacements = 0;
  int clears = 0;
  WithdrawalStage stage = WithdrawalStage.none;

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
    replacements++;
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

ResponseBody _json(int status, Map<String, dynamic> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  test(
    'injects bearer access token without exposing a hardcoded token',
    () async {
      final storage = _MemoryTokenStorage(
        const TokenPair(accessToken: 'access', refreshToken: 'refresh'),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      final refreshDio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      late String authorization;
      dio.httpClientAdapter = _Adapter((options) async {
        authorization = options.headers['Authorization'] as String;
        return _json(200, {'data': 'ok'});
      });
      dio.interceptors.add(
        AuthSessionInterceptor(
          client: dio,
          refreshClient: refreshDio,
          storage: storage,
          onSessionExpired: () {},
        ),
      );

      await dio.get('/protected');

      expect(authorization, 'Bearer access');
    },
  );

  test('concurrent 401 responses share one refresh and retry once', () async {
    final storage = _MemoryTokenStorage(
      const TokenPair(accessToken: 'expired', refreshToken: 'refresh-1'),
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    final refreshDio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    var refreshCalls = 0;
    var retriedCalls = 0;
    dio.httpClientAdapter = _Adapter((options) async {
      if (options.headers['Authorization'] == 'Bearer expired') {
        return _json(401, {'code': 'TOKEN_EXPIRED'});
      }
      retriedCalls++;
      return _json(200, {'data': 'ok'});
    });
    refreshDio.httpClientAdapter = _Adapter((options) async {
      if (options.path == '/auth/refresh') {
        refreshCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return _json(200, {
          'data': {'access_token': 'access-2', 'refresh_token': 'refresh-2'},
        });
      }
      retriedCalls++;
      return _json(200, {'data': 'ok'});
    });
    dio.interceptors.add(
      AuthSessionInterceptor(
        client: dio,
        refreshClient: refreshDio,
        storage: storage,
        onSessionExpired: () {},
      ),
    );

    await Future.wait([dio.get('/one'), dio.get('/two')]);

    expect(refreshCalls, 1);
    expect(storage.replacements, 1);
    expect(storage.tokens!.refreshToken, 'refresh-2');
    expect(retriedCalls, 2);
  });

  test('a late 401 from the old access token reuses rotated tokens', () async {
    final storage = _MemoryTokenStorage(
      const TokenPair(accessToken: 'expired', refreshToken: 'refresh-1'),
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    final refreshDio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    var refreshCalls = 0;
    dio.httpClientAdapter = _Adapter((options) async {
      if (options.headers['Authorization'] == 'Bearer expired') {
        if (options.path.endsWith('/slow')) {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        }
        return _json(401, {'code': 'TOKEN_EXPIRED'});
      }
      return _json(200, {'data': 'ok'});
    });
    refreshDio.httpClientAdapter = _Adapter((options) async {
      if (options.path == '/auth/refresh') {
        refreshCalls++;
        return _json(200, {
          'data': {'access_token': 'access-2', 'refresh_token': 'refresh-2'},
        });
      }
      return _json(200, {'data': 'ok'});
    });
    dio.interceptors.add(
      AuthSessionInterceptor(
        client: dio,
        refreshClient: refreshDio,
        storage: storage,
        onSessionExpired: () {},
      ),
    );

    await Future.wait([dio.get('/fast'), dio.get('/slow')]);

    expect(refreshCalls, 1);
  });

  test('refresh failure clears local session and never loops', () async {
    final storage = _MemoryTokenStorage(
      const TokenPair(accessToken: 'expired', refreshToken: 'bad-refresh'),
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    final refreshDio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    var protectedCalls = 0;
    var expiredNotifications = 0;
    dio.httpClientAdapter = _Adapter((options) async {
      protectedCalls++;
      return _json(401, {'code': 'TOKEN_EXPIRED'});
    });
    refreshDio.httpClientAdapter = _Adapter(
      (options) async => _json(401, {'code': 'INVALID_REFRESH_TOKEN'}),
    );
    dio.interceptors.add(
      AuthSessionInterceptor(
        client: dio,
        refreshClient: refreshDio,
        storage: storage,
        onSessionExpired: () => expiredNotifications++,
      ),
    );

    await expectLater(dio.get('/protected'), throwsA(isA<DioException>()));

    expect(storage.clears, 1);
    expect(expiredNotifications, 1);
    expect(protectedCalls, 1);
  });

  test('a refresh connection failure preserves the local session', () async {
    final storage = _MemoryTokenStorage(
      const TokenPair(accessToken: 'expired', refreshToken: 'refresh-1'),
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    final refreshDio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    var expiredNotifications = 0;
    dio.httpClientAdapter = _Adapter(
      (options) async => _json(401, {'code': 'TOKEN_EXPIRED'}),
    );
    refreshDio.httpClientAdapter = _Adapter((options) async {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    });
    dio.interceptors.add(
      AuthSessionInterceptor(
        client: dio,
        refreshClient: refreshDio,
        storage: storage,
        onSessionExpired: () => expiredNotifications++,
      ),
    );

    await expectLater(dio.get('/protected'), throwsA(isA<DioException>()));

    expect(storage.clears, 0);
    expect(expiredNotifications, 0);
    expect(storage.tokens, isNotNull);
  });

  test('a 401 after the single retry expires the rotated session', () async {
    final storage = _MemoryTokenStorage(
      const TokenPair(accessToken: 'expired', refreshToken: 'refresh-1'),
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    final refreshDio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    var protectedCalls = 0;
    var expiredNotifications = 0;
    dio.httpClientAdapter = _Adapter((options) async {
      protectedCalls++;
      return _json(401, {'code': 'TOKEN_EXPIRED'});
    });
    refreshDio.httpClientAdapter = _Adapter((options) async {
      if (options.path == '/auth/refresh') {
        return _json(200, {
          'data': {'access_token': 'access-2', 'refresh_token': 'refresh-2'},
        });
      }
      return _json(401, {'code': 'TOKEN_EXPIRED'});
    });
    dio.interceptors.add(
      AuthSessionInterceptor(
        client: dio,
        refreshClient: refreshDio,
        storage: storage,
        onSessionExpired: () => expiredNotifications++,
      ),
    );

    await expectLater(dio.get('/protected'), throwsA(isA<DioException>()));

    expect(protectedCalls, 1);
    expect(storage.tokens, isNull);
    expect(expiredNotifications, 1);
  });

  test(
    'a late refresh response cannot resurrect a logged-out session',
    () async {
      final storage = _MemoryTokenStorage(
        const TokenPair(accessToken: 'expired', refreshToken: 'refresh-1'),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      final refreshDio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      final refreshStarted = Completer<void>();
      final releaseRefresh = Completer<void>();
      dio.httpClientAdapter = _Adapter(
        (options) async => _json(401, {'code': 'TOKEN_EXPIRED'}),
      );
      refreshDio.httpClientAdapter = _Adapter((options) async {
        refreshStarted.complete();
        await releaseRefresh.future;
        return _json(200, {
          'data': {
            'access_token': 'late-access',
            'refresh_token': 'late-refresh',
          },
        });
      });
      dio.interceptors.add(
        AuthSessionInterceptor(
          client: dio,
          refreshClient: refreshDio,
          storage: storage,
          onSessionExpired: () {},
        ),
      );

      final request = dio.get('/protected');
      await refreshStarted.future;
      await storage.clear();
      releaseRefresh.complete();
      await expectLater(request, throwsA(isA<DioException>()));

      expect(storage.tokens, isNull);
    },
  );

  test('does not replay finalized multipart requests after refresh', () async {
    final storage = _MemoryTokenStorage(
      const TokenPair(accessToken: 'expired', refreshToken: 'refresh-1'),
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    final refreshDio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    var protectedCalls = 0;
    dio.httpClientAdapter = _Adapter((options) async {
      protectedCalls++;
      return _json(401, {'code': 'TOKEN_EXPIRED'});
    });
    refreshDio.httpClientAdapter = _Adapter((options) async {
      return _json(200, {
        'data': {'access_token': 'access-2', 'refresh_token': 'refresh-2'},
      });
    });
    dio.interceptors.add(
      AuthSessionInterceptor(
        client: dio,
        refreshClient: refreshDio,
        storage: storage,
        onSessionExpired: () {},
      ),
    );

    await expectLater(
      dio.post('/upload', data: FormData.fromMap({'field': 'value'})),
      throwsA(
        isA<DioException>().having(
          (error) => error.error,
          'explicit replay error',
          isA<AuthRequestNotReplayable>(),
        ),
      ),
    );

    expect(protectedCalls, 1);
    expect(storage.tokens!.accessToken, 'access-2');
  });
}
