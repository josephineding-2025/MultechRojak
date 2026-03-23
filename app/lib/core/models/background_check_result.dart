// ---------------------------------------------------------------------------
// Nested dossier models
// ---------------------------------------------------------------------------

class ScrapedProfile {
  final String? platform;
  final String? username;
  final String? bioText;
  final int? followerCount;
  final int? followingCount;
  final int? accountAgeDays;
  final int? postCount;
  final String? scrapeError;
  final String? rawUrl;

  const ScrapedProfile({
    this.platform,
    this.username,
    this.bioText,
    this.followerCount,
    this.followingCount,
    this.accountAgeDays,
    this.postCount,
    this.scrapeError,
    this.rawUrl,
  });

  factory ScrapedProfile.fromJson(Map<String, dynamic> json) => ScrapedProfile(
        platform: json['platform'] as String?,
        username: json['username'] as String?,
        bioText: json['bio_text'] as String?,
        followerCount: json['follower_count'] as int?,
        followingCount: json['following_count'] as int?,
        accountAgeDays: json['account_age_days'] as int?,
        postCount: json['post_count'] as int?,
        scrapeError: json['scrape_error'] as String?,
        rawUrl: json['raw_url'] as String?,
      );
}

class DiscoveredIdentifiers {
  final List<String> phones;
  final List<String> emails;
  final List<String> handles;
  final String? locationClaim;
  final String? occupationClaim;

  const DiscoveredIdentifiers({
    this.phones = const [],
    this.emails = const [],
    this.handles = const [],
    this.locationClaim,
    this.occupationClaim,
  });

  factory DiscoveredIdentifiers.fromJson(Map<String, dynamic> json) =>
      DiscoveredIdentifiers(
        phones: (json['phones'] as List? ?? []).map((e) => e as String).toList(),
        emails: (json['emails'] as List? ?? []).map((e) => e as String).toList(),
        handles:
            (json['handles'] as List? ?? []).map((e) => e as String).toList(),
        locationClaim: json['location_claim'] as String?,
        occupationClaim: json['occupation_claim'] as String?,
      );
}

class DossierFinding {
  final String category; // 'photo' | 'phone' | 'account' | 'username'
  final String severity; // 'critical' | 'high' | 'medium' | 'low'
  final String flag;
  final String evidence;

  const DossierFinding({
    required this.category,
    required this.severity,
    required this.flag,
    required this.evidence,
  });

  factory DossierFinding.fromJson(Map<String, dynamic> json) => DossierFinding(
        category: json['category'] as String,
        severity: json['severity'] as String,
        flag: json['flag'] as String,
        evidence: json['evidence'] as String,
      );
}

// ---------------------------------------------------------------------------
// Main result model
// ---------------------------------------------------------------------------

class BackgroundCheckResult {
  // Existing fields (unchanged)
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

  // New dossier fields
  final int? confidenceScore;
  final String? riskLevel;
  final ScrapedProfile? scrapedProfile;
  final DiscoveredIdentifiers? discoveredIdentifiers;
  final List<DossierFinding> findings;

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
    this.confidenceScore,
    this.riskLevel,
    this.scrapedProfile,
    this.discoveredIdentifiers,
    this.findings = const [],
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
        // New fields — null-safe, won't break old responses
        confidenceScore: json['confidence_score'] as int?,
        riskLevel: json['risk_level'] as String?,
        scrapedProfile: json['scraped_profile'] != null
            ? ScrapedProfile.fromJson(
                json['scraped_profile'] as Map<String, dynamic>)
            : null,
        discoveredIdentifiers: json['discovered_identifiers'] != null
            ? DiscoveredIdentifiers.fromJson(
                json['discovered_identifiers'] as Map<String, dynamic>)
            : null,
        findings: (json['findings'] as List? ?? [])
            .map((e) => DossierFinding.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
