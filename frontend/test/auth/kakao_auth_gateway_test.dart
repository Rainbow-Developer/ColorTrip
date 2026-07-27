import 'package:colortrip/data/auth/kakao_auth_gateway.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

class _SdkClient implements KakaoSdkClient {
  bool talkInstalled = true;
  Object? talkError;
  Object? accountError;
  int talkLogins = 0;
  int accountLogins = 0;
  int logouts = 0;
  int unlinks = 0;

  @override
  Future<bool> isTalkInstalled() async => talkInstalled;

  @override
  Future<String> loginWithAccount() async {
    accountLogins++;
    if (accountError case final error?) throw error;
    return 'account-token';
  }

  @override
  Future<String> loginWithTalk() async {
    talkLogins++;
    if (talkError case final error?) throw error;
    return 'talk-token';
  }

  @override
  Future<void> logout() async {
    logouts++;
  }

  @override
  Future<void> unlink() async {
    unlinks++;
  }
}

void main() {
  test('uses KakaoTalk when it is installed', () async {
    final client = _SdkClient();
    final gateway = KakaoSdkAuthGateway(client: client);

    expect(await gateway.login(), 'talk-token');
    expect(client.talkLogins, 1);
    expect(client.accountLogins, 0);
  });

  test(
    'falls back to Kakao Account after a non-cancellation Talk error',
    () async {
      final client = _SdkClient()..talkError = StateError('talk unavailable');
      final gateway = KakaoSdkAuthGateway(client: client);

      expect(await gateway.login(), 'account-token');
      expect(client.talkLogins, 1);
      expect(client.accountLogins, 1);
    },
  );

  test(
    'native Talk cancellation does not fall back to Kakao Account',
    () async {
      final client = _SdkClient()
        ..talkError = PlatformException(code: 'CANCELED');
      final gateway = KakaoSdkAuthGateway(client: client);

      await expectLater(gateway.login(), throwsA(isA<KakaoLoginCancelled>()));
      expect(client.accountLogins, 0);
    },
  );

  test(
    'classifies Kakao platform configuration failures without raw data',
    () async {
      final client = _SdkClient()
        ..talkInstalled = false
        ..accountError = KakaoAuthException(
          AuthErrorCause.misconfigured,
          'invalid android key hash',
        );
      final gateway = KakaoSdkAuthGateway(client: client);

      await expectLater(
        gateway.login(),
        throwsA(
          isA<KakaoLoginFailure>().having(
            (error) => error.reason,
            'reason',
            KakaoLoginFailureReason.platformMisconfigured,
          ),
        ),
      );
    },
  );

  test('delegates logout and unlink to the SDK client', () async {
    final client = _SdkClient();
    final gateway = KakaoSdkAuthGateway(client: client);

    await gateway.logout();
    await gateway.unlink();

    expect(client.logouts, 1);
    expect(client.unlinks, 1);
  });
}
