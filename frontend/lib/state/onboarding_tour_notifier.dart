import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 온보딩 투어 전체 단계 수 — 지도 탭 → 퀘스트 선택하러 가기 → 여행 시작하기 → 퀘스트 인증.
const kOnboardingTotalSteps = 4;

const _kStepKey = 'onboarding_step';
const _kSkippedKey = 'onboarding_skipped';

class OnboardingTourState {
  const OnboardingTourState({required this.step, required this.skipped});

  const OnboardingTourState.initial() : step = 0, skipped = false;

  /// 다음에 보여줄 단계(0-based). [kOnboardingTotalSteps] 이상이면 모든 단계를 마친 것.
  final int step;

  /// "다시 보지 않기"로 전체 투어를 영구 종료했는지 여부.
  final bool skipped;

  bool get isDone => skipped || step >= kOnboardingTotalSteps;
}

/// 앱 시작 시(main.dart) 미리 읽어와 초기값으로 주입한다 — 비동기 로딩을 기다리는 동안
/// 코치마크가 잘못된 위치에 깜빡이는 것을 막기 위함.
Future<OnboardingTourState> loadOnboardingTourState() async {
  final prefs = await SharedPreferences.getInstance();
  return OnboardingTourState(
    step: prefs.getInt(_kStepKey) ?? 0,
    skipped: prefs.getBool(_kSkippedKey) ?? false,
  );
}

/// 실제 화면(지도, 퀘스트 선택 버튼 등) 위에 순서대로 코치마크를 띄우는 온보딩 투어 상태.
class OnboardingTourNotifier extends Notifier<OnboardingTourState> {
  OnboardingTourNotifier(this._initial);

  final OnboardingTourState _initial;

  @override
  OnboardingTourState build() => _initial;

  /// 현재 단계의 코치마크를 확인하고 다음 단계로 넘어간다.
  Future<void> advance() async {
    final nextStep = state.step + 1;
    state = OnboardingTourState(step: nextStep, skipped: state.skipped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kStepKey, nextStep);
  }

  /// "다시 보지 않기" — 남은 단계를 포함해 투어를 영구 종료한다.
  Future<void> skipForever() async {
    state = OnboardingTourState(step: state.step, skipped: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSkippedKey, true);
  }

  /// 설정에서 "가이드 다시 보기"를 켰을 때 호출 — 처음부터 다시 시작한다.
  Future<void> restart() async {
    state = const OnboardingTourState.initial();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kStepKey);
    await prefs.remove(_kSkippedKey);
  }
}

final onboardingTourProvider =
    NotifierProvider<OnboardingTourNotifier, OnboardingTourState>(
      () => throw UnimplementedError(
        'main.dart에서 초기값을 로드한 뒤 overrideWith로 주입해야 합니다.',
      ),
    );
