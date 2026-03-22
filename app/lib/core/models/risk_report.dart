class RedFlag {
  final String pattern;
  final String evidence;
  final String severity;

  const RedFlag({
    required this.pattern,
    required this.evidence,
    required this.severity,
  });

  factory RedFlag.fromJson(Map<String, dynamic> json) => RedFlag(
        pattern: json['pattern'] as String,
        evidence: json['evidence'] as String,
        severity: json['severity'] as String,
      );
}

class RiskReport {
  final String riskLevel;
  final int riskScore;
  final List<RedFlag> redFlags;
  final String summary;
  final List<String> recommendedActions;

  const RiskReport({
    required this.riskLevel,
    required this.riskScore,
    required this.redFlags,
    required this.summary,
    required this.recommendedActions,
  });

  factory RiskReport.fromJson(Map<String, dynamic> json) => RiskReport(
        riskLevel: json['risk_level'] as String,
        riskScore: json['risk_score'] as int,
        redFlags: (json['red_flags'] as List)
            .map((e) => RedFlag.fromJson(e as Map<String, dynamic>))
            .toList(),
        summary: json['summary'] as String,
        recommendedActions: (json['recommended_actions'] as List)
            .map((e) => e as String)
            .toList(),
      );
}
