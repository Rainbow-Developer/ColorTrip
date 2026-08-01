import 'package:colortrip/data/models/auth_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UserProfile parses the complete backend profile contract', () {
    final user = UserProfile.fromJson({
      'id': '018f0000-0000-7000-8000-000000000001',
      'email': 'traveler@example.com',
      'nickname': '컬러트립',
      'birth_date': '2000-01-02',
      'profile_image': 'https://example.com/profile.png',
      'dna': 'nature',
      'social_provider': 'kakao',
      'onboarding_step': 'complete',
      'is_restored': false,
    });

    expect(user.id, '018f0000-0000-7000-8000-000000000001');
    expect(user.email, 'traveler@example.com');
    expect(user.nickname, '컬러트립');
    expect(user.birthDate, DateTime(2000, 1, 2));
    expect(user.profileImage, 'https://example.com/profile.png');
    expect(user.dna, 'nature');
    expect(user.onboardingStep, OnboardingStep.complete);
    expect(user.isRestored, isFalse);
  });

  test('UserProfile accepts nullable Kakao prefill fields', () {
    final user = UserProfile.fromJson({
      'id': '018f0000-0000-7000-8000-000000000001',
      'email': null,
      'nickname': null,
      'birth_date': null,
      'profile_image': null,
      'dna': null,
      'social_provider': 'kakao',
      'onboarding_step': 'profile',
      'is_restored': false,
    });

    expect(user.email, isNull);
    expect(user.nickname, isNull);
    expect(user.birthDate, isNull);
    expect(user.onboardingStep, OnboardingStep.profile);
  });

  test(
    'TokenPair rejects missing token fields instead of storing partial state',
    () {
      expect(
        () => TokenPair.fromJson({'access_token': 'access-only'}),
        throwsA(isA<FormatException>()),
      );
    },
  );
}
