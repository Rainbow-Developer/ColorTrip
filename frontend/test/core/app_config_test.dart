import 'package:colortrip/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts native key and absolute API base URL', () {
    final config = AppConfig.fromValues(
      kakaoNativeAppKey: 'native-key',
      apiBaseUrl: 'http://10.0.2.2:8000/api/v1',
    );

    expect(config.kakaoNativeAppKey, 'native-key');
    expect(config.apiBaseUrl, 'http://10.0.2.2:8000/api/v1');
  });

  test('reports all missing build definitions without revealing values', () {
    expect(
      () => AppConfig.fromValues(kakaoNativeAppKey: '', apiBaseUrl: ''),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('KAKAO_NATIVE_APP_KEY and API_BASE_URL'),
        ),
      ),
    );
  });

  test('reports only the missing Kakao native key', () {
    expect(
      () => AppConfig.fromValues(
        kakaoNativeAppKey: '',
        apiBaseUrl: 'http://10.0.2.2:8000/api/v1',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('KAKAO_NATIVE_APP_KEY build definition'),
        ),
      ),
    );
  });

  test('reports only the missing API base URL', () {
    expect(
      () =>
          AppConfig.fromValues(kakaoNativeAppKey: 'native-key', apiBaseUrl: ''),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('API_BASE_URL build definition'),
        ),
      ),
    );
  });

  test('rejects API URLs without http or https', () {
    expect(
      () => AppConfig.fromValues(
        kakaoNativeAppKey: 'native-key',
        apiBaseUrl: '10.0.2.2:8000',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('absolute HTTP(S) URL'),
        ),
      ),
    );
  });
}
