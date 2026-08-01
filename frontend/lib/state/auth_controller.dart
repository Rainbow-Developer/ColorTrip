import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth/kakao_auth_gateway.dart';
import '../data/models/auth_models.dart';
import 'repository_providers.dart';

enum AuthStatus {
  checking,
  unauthenticated,
  failure,
  profileRequired,
  tripDnaRequired,
  authenticated,
  withdrawalPending,
}

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.isBusy = false,
    this.errorMessage,
  });

  final AuthStatus status;
  final UserProfile? user;
  final bool isBusy;
  final String? errorMessage;
}

class AuthController extends Notifier<AuthState> {
  int _epoch = 0;

  @override
  AuthState build() => const AuthState(status: AuthStatus.checking);

  Future<void> bootstrap() async {
    final epoch = ++_epoch;
    state = const AuthState(status: AuthStatus.checking);
    final repository = ref.read(authRepositoryProvider);
    try {
      final user = await repository.restoreSession();
      if (epoch != _epoch) return;
      // Read the marker after restoration because an invalid token recovery
      // may have cleared the whole secure session.
      final pending = await repository.isWithdrawalPending();
      if (epoch != _epoch) return;
      if (pending) {
        state = AuthState(status: AuthStatus.withdrawalPending, user: user);
        return;
      }
      state = user == null
          ? const AuthState(status: AuthStatus.unauthenticated)
          : _stateForUser(user);
    } on Object {
      if (epoch != _epoch) return;
      state = const AuthState(
        status: AuthStatus.failure,
        errorMessage: '세션을 확인하지 못했습니다. 네트워크를 확인하고 다시 시도해주세요.',
      );
    }
  }

  Future<void> login() async {
    final epoch = ++_epoch;
    state = const AuthState(status: AuthStatus.unauthenticated, isBusy: true);
    try {
      final session = await ref.read(authRepositoryProvider).loginWithKakao();
      if (epoch != _epoch) return;
      state = _stateForUser(session.user);
    } on KakaoLoginCancelled {
      if (epoch != _epoch) return;
      state = const AuthState(status: AuthStatus.unauthenticated);
    } on Object catch (error) {
      if (epoch != _epoch) return;
      if (kDebugMode && error is KakaoLoginFailure) {
        debugPrint('Kakao login failed: ${error.reason.name}');
      }
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: authLoginErrorMessage(error),
      );
    }
  }

  Future<bool> submitOnboardingProfile(OnboardingProfileInput input) async {
    final epoch = _epoch;
    state = AuthState(status: state.status, user: state.user, isBusy: true);
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .submitOnboardingProfile(input);
      if (epoch != _epoch) return false;
      state = _stateForUser(user);
      return true;
    } on Object {
      if (epoch != _epoch) return false;
      try {
        final recovered = await ref
            .read(authRepositoryProvider)
            .fetchCurrentUser();
        if (epoch != _epoch) return false;
        if (recovered.onboardingStep != OnboardingStep.profile) {
          state = _stateForUser(recovered);
          return true;
        }
      } on Object {
        if (epoch != _epoch) return false;
      }
      state = AuthState(
        status: AuthStatus.profileRequired,
        user: state.user,
        errorMessage: '기본 정보를 저장하지 못했습니다. 입력값을 확인해주세요.',
      );
      return false;
    }
  }

  Future<bool> updateProfile(ProfileUpdateInput input) async {
    final epoch = _epoch;
    final previous = state;
    state = AuthState(
      status: previous.status,
      user: previous.user,
      isBusy: true,
    );
    try {
      final user = await ref.read(authRepositoryProvider).updateProfile(input);
      if (epoch != _epoch) return false;
      state = _stateForUser(user);
      return true;
    } on Object {
      if (epoch != _epoch) return false;
      state = AuthState(
        status: previous.status,
        user: previous.user,
        errorMessage: '프로필을 저장하지 못했습니다. 다시 시도해주세요.',
      );
      return false;
    }
  }

  Future<bool> refreshCurrentUser() async {
    final epoch = _epoch;
    try {
      final user = await ref.read(authRepositoryProvider).fetchCurrentUser();
      if (epoch != _epoch) return false;
      state = _stateForUser(user);
      return true;
    } on Object {
      if (epoch != _epoch) return false;
      state = AuthState(
        status: state.status,
        user: state.user,
        errorMessage: '사용자 정보를 새로고침하지 못했습니다.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    final epoch = ++_epoch;
    state = AuthState(status: state.status, user: state.user, isBusy: true);
    await ref.read(authRepositoryProvider).logout();
    if (epoch != _epoch) return;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> withdraw() async {
    final epoch = ++_epoch;
    final previous = state;
    state = AuthState(
      status: previous.status,
      user: previous.user,
      isBusy: true,
    );
    try {
      await ref.read(authRepositoryProvider).withdraw();
      if (epoch != _epoch) return;
      state = const AuthState(status: AuthStatus.unauthenticated);
    } on Object {
      if (epoch != _epoch) return;
      bool pending = false;
      try {
        pending = await ref.read(authRepositoryProvider).isWithdrawalPending();
      } on Object {
        // A storage read failure must not leave the controller in its busy state.
      }
      if (epoch != _epoch) return;
      state = AuthState(
        status: pending ? AuthStatus.withdrawalPending : previous.status,
        user: previous.user,
        errorMessage: pending
            ? '카카오 연결은 해제됐지만 회원 탈퇴를 완료하지 못했습니다.'
            : '카카오 연결 해제에 실패했습니다. 다시 시도해주세요.',
      );
    }
  }

  void sessionExpired() {
    _epoch++;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  AuthState _stateForUser(UserProfile user) => AuthState(
    status: switch (user.onboardingStep) {
      OnboardingStep.profile => AuthStatus.profileRequired,
      OnboardingStep.tripDna => AuthStatus.tripDnaRequired,
      OnboardingStep.complete => AuthStatus.authenticated,
    },
    user: user,
  );
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

final currentUserProvider = Provider<UserProfile?>(
  (ref) => ref.watch(authControllerProvider).user,
);

String authLoginErrorMessage(Object error) {
  if (error is KakaoLoginFailure) {
    return switch (error.reason) {
      KakaoLoginFailureReason.platformMisconfigured =>
        '카카오 개발자 설정의 Android 패키지명과 디버그 키 해시를 확인해주세요.',
      KakaoLoginFailureReason.invalidClient => '카카오 Native App Key 설정을 확인해주세요.',
      KakaoLoginFailureReason.invalidScope => '카카오 동의항목 설정을 확인해주세요.',
      KakaoLoginFailureReason.unauthorized => '카카오 로그인 사용 설정과 권한을 확인해주세요.',
      KakaoLoginFailureReason.network => '카카오 서버에 연결하지 못했습니다. 네트워크를 확인해주세요.',
      KakaoLoginFailureReason.server =>
        '카카오 로그인 서버가 응답하지 않습니다. 잠시 후 다시 시도해주세요.',
      KakaoLoginFailureReason.sdk => '카카오 로그인 SDK 설정을 확인해주세요.',
      KakaoLoginFailureReason.unknown => '카카오 인증을 완료하지 못했습니다. 잠시 후 다시 시도해주세요.',
    };
  }
  if (error is PlatformException) {
    return '카카오 로그인 설정을 확인해주세요.';
  }
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '로그인 요청 시간이 초과되었습니다. 잠시 후 다시 시도해주세요.';
      case DioExceptionType.connectionError:
        return '네트워크 연결을 확인하고 다시 시도해주세요.';
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }
    final data = error.response?.data;
    final code = data is Map<String, dynamic> ? data['code'] : null;
    if (code == 'SOCIAL_AUTH_ERROR') {
      return '카카오 인증 정보를 확인하지 못했습니다. 카카오 로그인을 다시 시도해주세요.';
    }
    if (error.response != null) {
      return 'ColorTrip 로그인 서버에 연결하지 못했습니다. 잠시 후 다시 시도해주세요.';
    }
  }
  return '카카오 로그인에 실패했습니다. 잠시 후 다시 시도해주세요.';
}
