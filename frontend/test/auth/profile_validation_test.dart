import 'package:colortrip/features/onboarding/profile_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts the backend nickname email and birth date constraints', () {
    final result = validateOnboardingProfile(
      nickname: '컬러트립',
      email: 'traveler@example.com',
      birthDate: '2000-01-02',
      today: DateTime(2026, 7, 25),
    );

    expect(result.errors, isEmpty);
    expect(result.birthDate, DateTime(2000, 1, 2));
  });

  test('rejects blank or too-long nickname and malformed email', () {
    expect(
      validateOnboardingProfile(
        nickname: ' ',
        email: 'not-an-email',
        birthDate: '2000-01-02',
        today: DateTime(2026, 7, 25),
      ).errors.keys,
      containsAll(['nickname', 'email']),
    );
    expect(
      validateOnboardingProfile(
        nickname: '가' * 31,
        email: 'traveler@example.com',
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
        email: 'traveler@example.com',
        birthDate: '2026-02-30',
        today: DateTime(2026, 7, 25),
      ).errors,
      contains('birthDate'),
    );
    expect(
      validateOnboardingProfile(
        nickname: '컬러트립',
        email: 'traveler@example.com',
        birthDate: '2026-07-26',
        today: DateTime(2026, 7, 25),
      ).errors,
      contains('birthDate'),
    );
    expect(
      validateOnboardingProfile(
        nickname: '컬러트립',
        email: 'traveler@example.com',
        birthDate: '1900-01-01',
        today: DateTime(2026, 7, 25),
      ).errors,
      contains('birthDate'),
    );
  });

  test('treats an empty birth date as valid and unset', () {
    // 생년월일은 선택 항목이다(KAN-75) — 비워두면 오류 없이 null이어야 한다.
    final result = validateOnboardingProfile(
      nickname: '컬러트립',
      email: 'traveler@example.com',
      birthDate: '   ',
      today: DateTime(2026, 7, 25),
    );

    expect(result.errors, isEmpty);
    expect(result.birthDate, isNull);
  });

  test('still rejects a malformed birth date when one is entered', () {
    final result = validateOnboardingProfile(
      nickname: '컬러트립',
      email: 'traveler@example.com',
      birthDate: '2000-1-2',
      today: DateTime(2026, 7, 25),
    );

    expect(result.errors, contains('birthDate'));
  });
}
