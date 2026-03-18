class BackgroundCheckResult {
  final bool photoFoundOnline;
  final List<String> photoSources;
  final List<String> usernamePlatforms;
  final bool phoneValid;
  final String phoneCountry;
  final String? phoneCarrier;
  final int profileConsistencyScore;
  final String backgroundSummary;
  final bool platformVerified;
  final int? platformFollowers;
  final int? platformAccountAgeDays;
  final String authenticityNote;
  final String? photoHash;

  const BackgroundCheckResult({
    required this.photoFoundOnline,
    required this.photoSources,
    required this.usernamePlatforms,
    required this.phoneValid,
    required this.phoneCountry,
    this.phoneCarrier,
    required this.profileConsistencyScore,
    required this.backgroundSummary,
    required this.platformVerified,
    this.platformFollowers,
    this.platformAccountAgeDays,
    required this.authenticityNote,
    this.photoHash,
  });

  factory BackgroundCheckResult.fromJson(Map<String, dynamic> json) =>
      BackgroundCheckResult(
        photoFoundOnline: json['photo_found_online'] as bool,
        photoSources:
            (json['photo_sources'] as List).map((e) => e as String).toList(),
        usernamePlatforms:
            (json['username_platforms'] as List).map((e) => e as String).toList(),
        phoneValid: json['phone_valid'] as bool,
        phoneCountry: json['phone_country'] as String,
        phoneCarrier: json['phone_carrier'] as String?,
        profileConsistencyScore: json['profile_consistency_score'] as int,
        backgroundSummary: json['background_summary'] as String,
        platformVerified: json['platform_verified'] as bool,
        platformFollowers: json['platform_followers'] as int?,
        platformAccountAgeDays: json['platform_account_age_days'] as int?,
        authenticityNote: json['authenticity_note'] as String,
        photoHash: json['photo_hash'] as String?,
      );
}
