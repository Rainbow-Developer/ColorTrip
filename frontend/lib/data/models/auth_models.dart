enum OnboardingStep {
  profile,
  tripDna,
  complete;

  static OnboardingStep fromJson(String value) => switch (value) {
    'profile' => profile,
    'trip_dna' => tripDna,
    'complete' => complete,
    _ => throw FormatException('Unknown onboarding step: $value'),
  };
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.nickname,
    required this.birthDate,
    required this.profileImage,
    required this.dna,
    required this.socialProvider,
    required this.onboardingStep,
    required this.isRestored,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final birthDate = json['birth_date'] as String?;
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String?,
      nickname: json['nickname'] as String?,
      birthDate: birthDate == null ? null : DateTime.parse(birthDate),
      profileImage: json['profile_image'] as String?,
      dna: json['dna'] as String?,
      socialProvider: json['social_provider'] as String,
      onboardingStep: OnboardingStep.fromJson(
        json['onboarding_step'] as String,
      ),
      isRestored: json['is_restored'] as bool? ?? false,
    );
  }

  final String id;
  final String? email;
  final String? nickname;
  final DateTime? birthDate;
  final String? profileImage;
  final String? dna;
  final String socialProvider;
  final OnboardingStep onboardingStep;
  final bool isRestored;
}

class TokenPair {
  const TokenPair({required this.accessToken, required this.refreshToken});

  factory TokenPair.fromJson(Map<String, dynamic> json) {
    final accessToken = json['access_token'];
    final refreshToken = json['refresh_token'];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        refreshToken is! String ||
        refreshToken.isEmpty) {
      throw const FormatException('A complete token pair is required.');
    }
    return TokenPair(accessToken: accessToken, refreshToken: refreshToken);
  }

  final String accessToken;
  final String refreshToken;

  Map<String, String> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
  };
}

class AuthSession {
  const AuthSession({required this.tokens, required this.user});

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    tokens: TokenPair.fromJson(json),
    user: UserProfile.fromJson(json['user'] as Map<String, dynamic>),
  );

  final TokenPair tokens;
  final UserProfile user;
}

class OnboardingProfileInput {
  const OnboardingProfileInput({
    required this.nickname,
    required this.email,
    required this.birthDate,
    required this.termsAgreed,
    required this.privacyAgreed,
    required this.marketingAgreed,
  });

  final String nickname;
  final String email;

  /// 선택 항목 — 입력하지 않으면 null이고 요청 본문에서 아예 빠진다(KAN-75).
  final DateTime? birthDate;
  final bool termsAgreed;
  final bool privacyAgreed;
  final bool marketingAgreed;

  Map<String, dynamic> toJson() => {
    'nickname': nickname.trim(),
    'email': email.trim(),
    if (birthDate case final value?) 'birth_date': _date(value),
    'terms_agreed': termsAgreed,
    'privacy_agreed': privacyAgreed,
    'marketing_agreed': marketingAgreed,
  };
}

class ProfileUpdateInput {
  const ProfileUpdateInput({required this.nickname, required this.birthDate});

  final String nickname;

  /// null이면 요청에서 생략한다 — 서버는 보내지 않은 필드를 건드리지 않으므로
  /// "생년월일을 비워둔 채 닉네임만 수정"이 가능해진다(KAN-75).
  final DateTime? birthDate;

  Map<String, dynamic> toJson() => {
    'nickname': nickname.trim(),
    if (birthDate case final value?) 'birth_date': _date(value),
  };
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
