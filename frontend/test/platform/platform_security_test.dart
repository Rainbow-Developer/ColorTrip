import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android permits emulator HTTP only in debug and disables backup', () {
    final mainManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final debugManifest = File(
      'android/app/src/debug/AndroidManifest.xml',
    ).readAsStringSync();

    expect(mainManifest, contains('android:allowBackup="false"'));
    expect(mainManifest, contains('android.permission.CAMERA'));
    expect(mainManifest, contains('android.permission.ACCESS_FINE_LOCATION'));
    expect(mainManifest, isNot(contains('android:networkSecurityConfig')));
    expect(
      mainManifest,
      isNot(contains('android:usesCleartextTraffic="true"')),
    );
    expect(debugManifest, contains('android:networkSecurityConfig'));
    expect(debugManifest, contains('android:usesCleartextTraffic="true"'));
    expect(
      File(
        'android/app/src/debug/res/xml/network_security_config.xml',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        'android/app/src/main/res/xml/network_security_config.xml',
      ).existsSync(),
      isFalse,
    );
  });

  test('iOS app configurations enable Keychain Sharing entitlements', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final debugProfile = File(
      'ios/Runner/DebugProfile.entitlements',
    ).readAsStringSync();
    final release = File('ios/Runner/Release.entitlements').readAsStringSync();

    expect(
      project,
      contains('CODE_SIGN_ENTITLEMENTS = Runner/DebugProfile.entitlements;'),
    );
    expect(
      project,
      contains('CODE_SIGN_ENTITLEMENTS = Runner/Release.entitlements;'),
    );
    expect(debugProfile, contains('<key>keychain-access-groups</key>'));
    expect(release, contains('<key>keychain-access-groups</key>'));
  });
}
