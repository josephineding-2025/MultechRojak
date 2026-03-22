class FlagScammerResult {
  final bool success;
  final String profileStatus;
  final int totalReports;

  const FlagScammerResult({
    required this.success,
    required this.profileStatus,
    required this.totalReports,
  });

  factory FlagScammerResult.fromJson(Map<String, dynamic> json) =>
      FlagScammerResult(
        success: json['success'] as bool,
        profileStatus: json['profile_status'] as String,
        totalReports: json['total_reports'] as int,
      );
}

class ProfileCheckResult {
  final bool flagged;
  final String? status;
  final int? reportCount;
  final String? firstReported;
  final List<String>? commonFlags;
  final String? region;

  const ProfileCheckResult({
    required this.flagged,
    this.status,
    this.reportCount,
    this.firstReported,
    this.commonFlags,
    this.region,
  });

  factory ProfileCheckResult.fromJson(Map<String, dynamic> json) =>
      ProfileCheckResult(
        flagged: json['flagged'] as bool,
        status: json['status'] as String?,
        reportCount: json['report_count'] as int?,
        firstReported: json['first_reported'] as String?,
        commonFlags: (json['common_flags'] as List?)
            ?.map((e) => e as String)
            .toList(),
        region: json['region'] as String?,
      );
}
