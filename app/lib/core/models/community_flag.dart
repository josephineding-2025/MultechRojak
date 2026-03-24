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

  Map<String, dynamic> toJson() => {
        'success': success,
        'profile_status': profileStatus,
        'total_reports': totalReports,
      };
}

class ProfileCheckResult {
  final bool flagged;
  final String? status;
  final int? reportCount;
  final String? firstReported;
  final List<String>? commonFlags;
  final String? region;
  final String? photoHash;
  final String? handle;

  const ProfileCheckResult({
    required this.flagged,
    this.status,
    this.reportCount,
    this.firstReported,
    this.commonFlags,
    this.region,
    this.photoHash,
    this.handle,
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
        photoHash: json['photo_hash'] as String?,
        handle: json['handle'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'flagged': flagged,
        'status': status,
        'report_count': reportCount,
        'first_reported': firstReported,
        'common_flags': commonFlags,
        'region': region,
        'photo_hash': photoHash,
        'handle': handle,
      };
}

class CommunityFeedEntry {
  const CommunityFeedEntry({
    this.handle,
    this.platform,
    this.region,
    this.status,
    this.reportCount,
    this.lastReported,
    this.commonFlags,
  });

  final String? handle;
  final String? platform;
  final String? region;
  final String? status;
  final int? reportCount;
  final String? lastReported;
  final List<String>? commonFlags;

  factory CommunityFeedEntry.fromJson(Map<String, dynamic> j) =>
      CommunityFeedEntry(
        handle: j['handle'] as String?,
        platform: j['platform'] as String?,
        region: j['region'] as String?,
        status: j['status'] as String?,
        reportCount: j['report_count'] as int?,
        lastReported: j['last_reported'] as String?,
        commonFlags:
            (j['common_flags'] as List<dynamic>?)?.cast<String>(),
      );
}
