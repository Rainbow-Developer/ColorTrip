import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

import '../models/auth_models.dart';

abstract interface class SecureTokenStorage {
  Future<TokenPair?> read();
  Future<void> replace(TokenPair tokens, {bool preserveWithdrawalState = true});
  Future<bool> replaceIfRefreshToken(
    String expectedRefreshToken,
    TokenPair tokens,
  );
  Future<bool> clearIfRefreshToken(String expectedRefreshToken);
  Future<void> markWithdrawalUnlinkPending();
  Future<void> markWithdrawalPending();
  Future<WithdrawalStage> withdrawalStage();
  Future<bool> isWithdrawalPending();
  Future<void> clear();
}

enum WithdrawalStage { none, unlinkPending, backendPending }

abstract interface class SecureKeyValueStore {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  const FlutterSecureKeyValueStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) async {
    try {
      return await _storage.read(key: key);
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> write({required String key, required String value}) async {
    try {
      await _storage.write(key: key, value: value);
    } on PlatformException {
      // A Keystore/Keychain reset makes the previous session unavailable.
      // The caller can continue as an unauthenticated user instead of failing
      // during app bootstrap.
    }
  }

  @override
  Future<void> delete({required String key}) async {
    try {
      await _storage.delete(key: key);
    } on PlatformException {
      // Deletion is best-effort after a platform secure-storage failure.
    }
  }
}

class JsonSecureTokenStorage implements SecureTokenStorage {
  JsonSecureTokenStorage(this._store);

  static const _sessionKey = 'colortrip.auth.token-pair.v1';
  static const _withdrawalStageKey = 'withdrawal_stage';
  static const _withdrawalStageStorageKey =
      'colortrip.auth.withdrawal-stage.v1';

  final SecureKeyValueStore _store;
  Future<void> _operationTail = Future<void>.value();

  @override
  Future<TokenPair?> read() =>
      _exclusive(() async => (await _readStoredSession()).tokens);

  @override
  Future<void> replace(
    TokenPair tokens, {
    bool preserveWithdrawalState = true,
  }) => _exclusive(() async {
    if (!preserveWithdrawalState) {
      await _store.delete(key: _withdrawalStageStorageKey);
    }
    final current = await _readStoredSession();
    await _write(
      tokens,
      preserveWithdrawalState ? current.stage : WithdrawalStage.none,
    );
  });

  @override
  Future<bool> replaceIfRefreshToken(
    String expectedRefreshToken,
    TokenPair tokens,
  ) => _exclusive(() async {
    final current = await _readStoredSession();
    if (current.tokens?.refreshToken != expectedRefreshToken) return false;
    await _write(tokens, current.stage);
    return true;
  });

  @override
  Future<bool> clearIfRefreshToken(String expectedRefreshToken) =>
      _exclusive(() async {
        final current = await _readStoredSession();
        if (current.tokens?.refreshToken != expectedRefreshToken) return false;
        await _store.delete(key: _sessionKey);
        return true;
      });

  @override
  Future<void> markWithdrawalUnlinkPending() =>
      _setWithdrawalStage(WithdrawalStage.unlinkPending);

  @override
  Future<void> markWithdrawalPending() =>
      _setWithdrawalStage(WithdrawalStage.backendPending);

  @override
  Future<WithdrawalStage> withdrawalStage() => _exclusive(() async {
    final stored = await _store.read(key: _withdrawalStageStorageKey);
    final stage = _stageFromValue(stored);
    return stage ?? (await _readStoredSession()).stage;
  });

  @override
  Future<bool> isWithdrawalPending() async =>
      await withdrawalStage() != WithdrawalStage.none;

  @override
  Future<void> clear() => _exclusive(() async {
    await _store.delete(key: _sessionKey);
    await _store.delete(key: _withdrawalStageStorageKey);
  });

  Future<void> _setWithdrawalStage(WithdrawalStage stage) =>
      _exclusive(() async {
        await _store.write(
          key: _withdrawalStageStorageKey,
          value: switch (stage) {
            WithdrawalStage.none => 'none',
            WithdrawalStage.unlinkPending => 'unlink_pending',
            WithdrawalStage.backendPending => 'backend_pending',
          },
        );
      });

  WithdrawalStage? _stageFromValue(String? value) => switch (value) {
    'unlink_pending' => WithdrawalStage.unlinkPending,
    'backend_pending' => WithdrawalStage.backendPending,
    'none' => WithdrawalStage.none,
    _ => null,
  };

  Future<_StoredSession> _readStoredSession() async {
    final encoded = await _store.read(key: _sessionKey);
    if (encoded == null) return const _StoredSession();
    try {
      final value = jsonDecode(encoded) as Map<String, dynamic>;
      return _StoredSession(
        tokens: TokenPair.fromJson(value),
        stage: _decodeWithdrawalStage(value),
      );
    } on Object {
      await _store.delete(key: _sessionKey);
      return const _StoredSession();
    }
  }

  WithdrawalStage _decodeWithdrawalStage(Map<String, dynamic> value) {
    return switch (value[_withdrawalStageKey]) {
      'unlink_pending' => WithdrawalStage.unlinkPending,
      'backend_pending' => WithdrawalStage.backendPending,
      _ when value['withdrawal_pending'] == true =>
        WithdrawalStage.backendPending,
      _ => WithdrawalStage.none,
    };
  }

  Future<void> _write(TokenPair tokens, WithdrawalStage stage) => _store.write(
    key: _sessionKey,
    value: jsonEncode({
      ...tokens.toJson(),
      _withdrawalStageKey: switch (stage) {
        WithdrawalStage.none => 'none',
        WithdrawalStage.unlinkPending => 'unlink_pending',
        WithdrawalStage.backendPending => 'backend_pending',
      },
    }),
  );

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _operationTail = _operationTail.then((_) async {
      try {
        completer.complete(await action());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}

class _StoredSession {
  const _StoredSession({this.tokens, this.stage = WithdrawalStage.none});

  final TokenPair? tokens;
  final WithdrawalStage stage;
}
