import 'package:colortrip/data/auth/secure_token_storage.dart';
import 'package:colortrip/data/models/auth_models.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemorySecureStore implements SecureKeyValueStore {
  String? value;
  int writes = 0;
  int deletes = 0;

  @override
  Future<void> delete({required String key}) async {
    deletes++;
    value = null;
  }

  @override
  Future<String?> read({required String key}) async => value;

  @override
  Future<void> write({required String key, required String value}) async {
    writes++;
    this.value = value;
  }
}

void main() {
  test('stores both rotated tokens in one secure write', () async {
    final store = _MemorySecureStore();
    final storage = JsonSecureTokenStorage(store);
    const pair = TokenPair(
      accessToken: 'new-access',
      refreshToken: 'new-refresh',
    );

    await storage.replace(pair);

    expect(store.writes, 1);
    expect(await storage.read(), isA<TokenPair>());
    expect((await storage.read())!.accessToken, 'new-access');
    expect((await storage.read())!.refreshToken, 'new-refresh');
  });

  test('clears corrupted partial token state', () async {
    final store = _MemorySecureStore()..value = '{"access_token":"only"}';
    final storage = JsonSecureTokenStorage(store);

    expect(await storage.read(), isNull);
    expect(store.deletes, 1);
  });

  test('persists withdrawal pending state with the token pair', () async {
    final store = _MemorySecureStore();
    final storage = JsonSecureTokenStorage(store);
    await storage.replace(
      const TokenPair(accessToken: 'access', refreshToken: 'refresh'),
    );

    await storage.markWithdrawalPending();

    expect(await storage.isWithdrawalPending(), isTrue);
    expect((await storage.read())!.accessToken, 'access');
  });

  test('preserves withdrawal stage while rotating tokens', () async {
    final store = _MemorySecureStore();
    final storage = JsonSecureTokenStorage(store);
    await storage.replace(
      const TokenPair(accessToken: 'old-access', refreshToken: 'old-refresh'),
    );
    await storage.markWithdrawalPending();

    await storage.replace(
      const TokenPair(accessToken: 'new-access', refreshToken: 'new-refresh'),
    );

    expect(await storage.isWithdrawalPending(), isTrue);
    expect((await storage.read())!.refreshToken, 'new-refresh');
  });

  test('compare-and-swap does not resurrect a cleared session', () async {
    final store = _MemorySecureStore();
    final storage = JsonSecureTokenStorage(store);
    await storage.replace(
      const TokenPair(accessToken: 'old-access', refreshToken: 'old-refresh'),
    );
    await storage.clear();

    final replaced = await storage.replaceIfRefreshToken(
      'old-refresh',
      const TokenPair(accessToken: 'late-access', refreshToken: 'late-refresh'),
    );

    expect(replaced, isFalse);
    expect(await storage.read(), isNull);
  });

  test('compare-and-swap does not overwrite a newer login', () async {
    final store = _MemorySecureStore();
    final storage = JsonSecureTokenStorage(store);
    await storage.replace(
      const TokenPair(accessToken: 'old-access', refreshToken: 'old-refresh'),
    );
    await storage.replace(
      const TokenPair(
        accessToken: 'login-access',
        refreshToken: 'login-refresh',
      ),
    );

    final replaced = await storage.replaceIfRefreshToken(
      'old-refresh',
      const TokenPair(accessToken: 'late-access', refreshToken: 'late-refresh'),
    );

    expect(replaced, isFalse);
    expect((await storage.read())!.refreshToken, 'login-refresh');
  });
}
