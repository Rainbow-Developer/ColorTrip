import 'package:colortrip/features/onboarding/profile_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts the backend nickname and birth date constraints', () {
    final result = validateOnboardingProfile(
      nickname: '컬러트립',
      birthDate: '2000-01-02',
      today: DateTime(2026, 7, 25),
    );

    expect(result.errors, isEmpty);
    expect(result.birthDate, DateTime(2000, 1, 2));
  });

  test('rejects blank or too-long nickname', () {
    expect(
      validateOnboardingProfile(
        nickname: ' ',
        birthDate: '2000-01-02',
        today: DateTime(2026, 7, 25),
      ).errors,
      contains('nickname'),
    );
    expect(
      validateOnboardingProfile(
        nickname: '가' * 31,
        birthDate: '2000-01-02',
        today: DateTime(2026, 7, 25),
      ).errors,
      contains('nickname'),
    );
  });

  test('rejects invalid and future birth dates', () {
    expect(
      validateOnboardingProfile(
        nickname: '컬러트립',
        birthDate: '2026-02-30',
        today: DateTime(2026, 7, 25),
      ).errors,
      contains('birthDate'),
    );
    expect(
      validateOnboardingProfile(
        nickname: '컬러트립',
        birthDate: '2026-07-26',
        today: DateTime(2026, 7, 25),
      ).errors,
      contains('birthDate'),
    );
    expect(
      validateOnboardingProfile(
        nickname: '컬러트립',
        birthDate: '1900-01-01',
        today: DateTime(2026, 7, 25),
      ).errors,
      contains('birthDate'),
    );
  });

  test('rejects a birth date for a user younger than fourteen', () {
    final result = validateOnboardingProfile(
      nickname: '컬러트립',
      birthDate: '2013-07-26',
      today: DateTime(2026, 7, 25),
    );

    expect(result.errors, contains('birthDate'));
  });

  test('rejects a malformed birth date', () {
    final result = validateOnboardingProfile(
      nickname: '컬러트립',
      birthDate: '2000-1-2',
      today: DateTime(2026, 7, 25),
    );

    expect(result.errors, contains('birthDate'));
  });
}
