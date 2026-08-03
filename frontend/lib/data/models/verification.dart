/// 퀘스트 인증 API 판정 결과 모델(docs/specs/050-quest-verification).
library;

/// 사진 AI 인증 판정(`POST /verifications/photo`) 결과.
class PhotoVerdict {
  const PhotoVerdict({
    required this.passed,
    required this.confidence,
    required this.reason,
    required this.provider,
  });

  factory PhotoVerdict.fromJson(Map<String, dynamic> json) => PhotoVerdict(
    passed: json['passed'] as bool? ?? false,
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    reason: json['reason'] as String? ?? '',
    provider: json['provider'] as String? ?? 'stub',
  );

  final bool passed;

  /// 0~1 신뢰도.
  final double confidence;

  /// 판정 사유(통과·거절 모두 채워진다).
  final String reason;

  /// 판정 제공자 — `gemini` 또는 `stub`(GEMINI_API_KEY 미설정 시).
  final String provider;

  /// 스텁 판정 여부 — 결과 화면에서 "AI 미설정" 뱃지를 띄운다.
  bool get isStub => provider == 'stub';
}

/// QR 인증 검증(`POST /verifications/qr`) 결과.
class QrVerdict {
  const QrVerdict({required this.passed, required this.reason});

  factory QrVerdict.fromJson(Map<String, dynamic> json) => QrVerdict(
    passed: json['passed'] as bool? ?? false,
    reason: json['reason'] as String? ?? '',
  );

  final bool passed;
  final String reason;
}
