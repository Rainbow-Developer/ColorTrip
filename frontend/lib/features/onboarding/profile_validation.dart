class ProfileValidationResult {
  const ProfileValidationResult({required this.errors, this.birthDate});

  final Map<String, String> errors;

  /// 파싱된 생년월일 — **선택 항목**이라 입력이 비었으면 오류 없이 null이다(KAN-75).
  /// 오류 없이 null인 경우와 오류가 있어 null인 경우는 [errors]로 구분한다.
  final DateTime? birthDate;
}

/// Date-picker and form validation share the same supported birth-date range.
DateTime minimumBirthDate(DateTime today) => DateTime(today.year - 120);

ProfileValidationResult validateOnboardingProfile({
  required String nickname,
  required String email,
  required String birthDate,
  required DateTime today,
}) {
  final errors = <String, String>{};
  final normalizedNickname = nickname.trim();
  final normalizedEmail = email.trim();

  if (normalizedNickname.isEmpty || normalizedNickname.length > 30) {
    errors['nickname'] = '닉네임은 1~30자로 입력해주세요.';
  }
  final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (normalizedEmail.length > 255 || !emailPattern.hasMatch(normalizedEmail)) {
    errors['email'] = '올바른 이메일을 입력해주세요.';
  }

  // 생년월일은 선택 항목이다(KAN-75) — 비워두면 검증 없이 통과하고 null을 돌려준다.
  // 값이 있을 때만 형식·범위를 따진다.
  final normalizedBirthDate = birthDate.trim();
  if (normalizedBirthDate.isEmpty) {
    return ProfileValidationResult(errors: errors, birthDate: null);
  }

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
      parsedBirthDate.isAfter(todayOnly)) {
    errors['birthDate'] = '유효한 생년월일을 입력해주세요.';
  }

  return ProfileValidationResult(
    errors: errors,
    birthDate: errors.containsKey('birthDate') ? null : parsedBirthDate,
  );
}
