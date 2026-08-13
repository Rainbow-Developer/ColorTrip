import 'package:colortrip/core/config/app_config.dart';
import 'package:colortrip/core/network/dio_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String? Function(String?) _resolver({
  String apiBaseUrl = 'https://api.example.com/api/v1',
}) {
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig.fromValues(
          kakaoNativeAppKey: 'test-native-key',
          apiBaseUrl: apiBaseUrl,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container.read(resolveUploadUrlProvider);
}

void main() {
  test('상대 경로는 apiBaseUrl의 origin에 붙는다', () {
    final resolve = _resolver();

    // `/api/v1` 경로가 아니라 origin 기준이어야 정적 서빙 경로와 맞는다.
    expect(
      resolve('/uploads/avatars/2026/08/a.png'),
      'https://api.example.com/uploads/avatars/2026/08/a.png',
    );
  });

  test('GCS 절대 URL은 그대로 통과한다', () {
    final resolve = _resolver();
    const url = 'https://storage.googleapis.com/bucket/avatars/2026/08/a.png';

    expect(resolve(url), url);
  });

  test('카카오 CDN 절대 URL은 그대로 통과한다', () {
    final resolve = _resolver();
    const url = 'https://k.kakaocdn.net/dn/profile/img_640x640.jpg';

    expect(resolve(url), url);
  });

  test('null과 공백은 null이 되어 placeholder로 이어진다', () {
    final resolve = _resolver();

    expect(resolve(null), isNull);
    expect(resolve(''), isNull);
    expect(resolve('   '), isNull);
  });

  test('포트가 있는 개발 서버 주소에서도 origin을 유지한다', () {
    final resolve = _resolver(apiBaseUrl: 'http://10.0.2.2:8000/api/v1');

    expect(
      resolve('/uploads/photos/2026/08/b.jpg'),
      'http://10.0.2.2:8000/uploads/photos/2026/08/b.jpg',
    );
  });
}
