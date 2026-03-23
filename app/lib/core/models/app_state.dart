import 'dart:convert';

import '../../features/background_check/background_check_utils.dart';

class AppSettings {
  const AppSettings({
    this.communityContributionEnabled = true,
  });

  final bool communityContributionEnabled;

  Map<String, dynamic> toJson() => {
        'community_contribution_enabled': communityContributionEnabled,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        communityContributionEnabled:
            json['community_contribution_enabled'] as bool? ?? true,
      );
}

class CommunityFlagEligibility {
  const CommunityFlagEligibility({
    required this.sourceType,
    required this.sourceRiskLevel,
    required this.sourceSessionId,
    this.platform,
    this.handle,
    this.phone,
    this.photoHash,
  });

  final String sourceType;
  final String sourceRiskLevel;
  final String sourceSessionId;
  final String? platform;
  final String? handle;
  final String? phone;
  final String? photoHash;

  bool get isEligible => isRiskLevelEligibleForCommunity(sourceRiskLevel);

  Map<String, dynamic> toJson() => {
        'source_type': sourceType,
        'source_risk_level': sourceRiskLevel,
        'source_session_id': sourceSessionId,
        'platform': platform,
        'handle': handle,
        'phone': phone,
        'photo_hash': photoHash,
      };

  String encode() => jsonEncode(toJson());

  factory CommunityFlagEligibility.fromJson(Map<String, dynamic> json) =>
      CommunityFlagEligibility(
        sourceType: json['source_type'] as String? ?? 'unknown',
        sourceRiskLevel: json['source_risk_level'] as String? ?? 'LOW',
        sourceSessionId: json['source_session_id'] as String? ?? '',
        platform: json['platform'] as String?,
        handle: json['handle'] as String?,
        phone: json['phone'] as String?,
        photoHash: json['photo_hash'] as String?,
      );

  factory CommunityFlagEligibility.decode(String raw) =>
      CommunityFlagEligibility.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
}

class LastCommunityLookup {
  const LastCommunityLookup({
    this.handle,
    this.phone,
  });

  final String? handle;
  final String? phone;

  bool get hasIdentifier =>
      (handle != null && handle!.trim().isNotEmpty) ||
      (phone != null && phone!.trim().isNotEmpty);

  Map<String, dynamic> toJson() => {
        'handle': handle,
        'phone': phone,
      };

  String encode() => jsonEncode(toJson());

  factory LastCommunityLookup.fromJson(Map<String, dynamic> json) =>
      LastCommunityLookup(
        handle: json['handle'] as String?,
        phone: json['phone'] as String?,
      );

  factory LastCommunityLookup.decode(String raw) => LastCommunityLookup.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
}
