class ProfileValidationResult {
  const ProfileValidationResult({required this.errors, this.birthDate});

  final Map<String, String> errors;

  /// 파싱된 생년월일 — 필수 항목이라 [errors]가 비어 있으면 항상 non-null이다.
  final DateTime? birthDate;
}

/// Date-picker and form validation share the same supported birth-date range.
DateTime minimumBirthDate(DateTime today) => DateTime(today.year - 120);

DateTime maximumBirthDate(DateTime today) =>
    DateTime(today.year - 14, today.month, today.day);

ProfileValidationResult validateOnboardingProfile({
  required String nickname,
  required String birthDate,
  required DateTime today,
}) {
  final errors = <String, String>{};
  final normalizedNickname = nickname.trim();

  if (normalizedNickname.isEmpty || normalizedNickname.length > 30) {
    errors['nickname'] = '닉네임은 1~30자로 입력해주세요.';
  }

  final normalizedBirthDate = birthDate.trim();
  final match = RegExp(
    r'^(\d{4})[-.](\d{2})[-.](\d{2})$',
  ).firstMatch(normalizedBirthDate);
  DateTime? parsedBirthDate;
  if (match != null) {
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final candidate = DateTime(year, month, day);
    if (candidate.year == year &&
        candidate.month == month &&
        candidate.day == day) {
      parsedBirthDate = candidate;
    }
  }
  final todayOnly = DateTime(today.year, today.month, today.day);
  if (parsedBirthDate == null ||
      parsedBirthDate.isBefore(minimumBirthDate(todayOnly)) ||
      parsedBirthDate.isAfter(maximumBirthDate(todayOnly))) {
    errors['birthDate'] = '만 14세 이상만 가입할 수 있어요.';
  }

  return ProfileValidationResult(
    errors: errors,
    birthDate: errors.containsKey('birthDate') ? null : parsedBirthDate,
  );
}
