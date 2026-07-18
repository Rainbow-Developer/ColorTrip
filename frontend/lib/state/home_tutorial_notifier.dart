import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "다시 보지 않기" 여부를 기기에 영구 저장하는 키. 앱을 재시작해도 유지된다.
const _kHomeTutorialDismissedKey = 'home_tutorial_dismissed';

/// 앱 시작 시(main.dart) 미리 읽어와 [HomeTutorialNotifier]의 초기값으로 주입한다 —
/// 비동기 로딩을 기다리는 동안 가이드가 잘못 깜빡이는 것을 막기 위함.
Future<bool> loadHomeTutorialDismissed() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kHomeTutorialDismissedKey) ?? false;
}

/// 홈 화면 최초 안내 가이드의 노출 여부 상태. true면 더 이상 자동으로 뜨지 않는다.
class HomeTutorialNotifier extends Notifier<bool> {
  HomeTutorialNotifier(this._initial);

  final bool _initial;

  @override
  bool build() => _initial;

  /// 가이드를 닫는다. [persist]가 true면("다시 보지 않기") 기기에 저장해 다음 실행에도 유지하고,
  /// false면 이번 세션에서만 닫히고 다음에 앱을 다시 열면 다시 노출된다.
  Future<void> dismiss({required bool persist}) async {
    state = true;
    if (persist) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kHomeTutorialDismissedKey, true);
    }
  }

  /// 설정에서 "가이드 다시 보기"를 켰을 때 호출 — 저장된 값을 지우고 즉시 다시 노출한다.
  Future<void> showAgain() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kHomeTutorialDismissedKey);
    state = false;
  }
}

final homeTutorialDismissedProvider =
    NotifierProvider<HomeTutorialNotifier, bool>(
      () => throw UnimplementedError(
        'main.dart에서 초기값을 로드한 뒤 overrideWith로 주입해야 합니다.',
      ),
    );
