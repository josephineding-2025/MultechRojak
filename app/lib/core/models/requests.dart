import 'package:flutter/foundation.dart';

@immutable
class ChatAnalysisRequestDto {
  const ChatAnalysisRequestDto({
    required this.platform,
    required this.sessionId,
    required this.frames,
  });

  final String platform;
  final String sessionId;
  final List<String> frames;

  @override
  bool operator ==(Object other) {
    return other is ChatAnalysisRequestDto &&
        other.platform == platform &&
        other.sessionId == sessionId &&
        listEquals(other.frames, frames);
  }

  @override
  int get hashCode => Object.hash(platform, sessionId, Object.hashAll(frames));
}

@immutable
class BackgroundCheckRequestDto {
  const BackgroundCheckRequestDto({
    this.username = '',
    this.platform = 'Other',
    this.phone,
    this.photoB64,
    this.profileUrl,
  });

  final String username;
  final String platform;
  final String? phone;
  final String? photoB64;
  final String? profileUrl;

  @override
  bool operator ==(Object other) {
    return other is BackgroundCheckRequestDto &&
        other.username == username &&
        other.platform == platform &&
        other.phone == phone &&
        other.photoB64 == photoB64 &&
        other.profileUrl == profileUrl;
  }

  @override
  int get hashCode =>
      Object.hash(username, platform, phone, photoB64, profileUrl);
}

@immutable
class BackgroundCheckStreamRequestDto {
  const BackgroundCheckStreamRequestDto({
    required this.profileUrl,
    this.username = '',
    this.platform = 'Other',
    this.phone,
  });

  final String profileUrl;
  final String username;
  final String platform;
  final String? phone;

  Map<String, String> toQueryParameters() => {
        'profile_url': profileUrl,
        if (username.isNotEmpty) 'username': username,
        'platform': platform,
        if (phone != null && phone!.isNotEmpty) 'phone': phone!,
      };

  @override
  bool operator ==(Object other) {
    return other is BackgroundCheckStreamRequestDto &&
        other.profileUrl == profileUrl &&
        other.username == username &&
        other.platform == platform &&
        other.phone == phone;
  }

  @override
  int get hashCode => Object.hash(profileUrl, username, platform, phone);
}

@immutable
class CommunityProfileLookupDto {
  const CommunityProfileLookupDto({
    this.handle,
    this.phone,
    this.photoHash,
  });

  final String? handle;
  final String? phone;
  final String? photoHash;

  bool get hasIdentifier =>
      (handle != null && handle!.trim().isNotEmpty) ||
      (phone != null && phone!.trim().isNotEmpty) ||
      (photoHash != null && photoHash!.trim().isNotEmpty);

  Map<String, String> toQueryParameters() => {
        if (handle != null && handle!.trim().isNotEmpty) 'handle': handle!,
        if (phone != null && phone!.trim().isNotEmpty) 'phone': phone!,
        if (photoHash != null && photoHash!.trim().isNotEmpty)
          'photo_hash': photoHash!,
      };

  @override
  bool operator ==(Object other) {
    return other is CommunityProfileLookupDto &&
        other.handle == handle &&
        other.phone == phone &&
        other.photoHash == photoHash;
  }

  @override
  int get hashCode => Object.hash(handle, phone, photoHash);
}

@immutable
class CommunityFlagRequestDto {
  const CommunityFlagRequestDto({
    required this.platform,
    this.handle,
    this.phone,
    this.photoHash,
    required this.flags,
    required this.region,
    required this.sourceType,
    required this.sourceRiskLevel,
    required this.sourceSessionId,
  });

  final String platform;
  final String? handle;
  final String? phone;
  final String? photoHash;
  final List<String> flags;
  final String region;
  final String sourceType;
  final String sourceRiskLevel;
  final String sourceSessionId;

  Map<String, dynamic> toJson() => {
        'platform': platform,
        if (handle != null && handle!.trim().isNotEmpty) 'handle': handle,
        if (phone != null && phone!.trim().isNotEmpty) 'phone': phone,
        if (photoHash != null && photoHash!.trim().isNotEmpty)
          'photo_hash': photoHash,
        'flags': flags,
        'region': region,
        'source_type': sourceType,
        'source_risk_level': sourceRiskLevel,
        'source_session_id': sourceSessionId,
      };

  @override
  bool operator ==(Object other) {
    return other is CommunityFlagRequestDto &&
        other.platform == platform &&
        other.handle == handle &&
        other.phone == phone &&
        other.photoHash == photoHash &&
        listEquals(other.flags, flags) &&
        other.region == region &&
        other.sourceType == sourceType &&
        other.sourceRiskLevel == sourceRiskLevel &&
        other.sourceSessionId == sourceSessionId;
  }

  @override
  int get hashCode => Object.hash(
        platform,
        handle,
        phone,
        photoHash,
        Object.hashAll(flags),
        region,
        sourceType,
        sourceRiskLevel,
        sourceSessionId,
      );
}

@immutable
class VideoFrameAnalysisRequestDto {
  const VideoFrameAnalysisRequestDto({
    required this.frameB64,
    required this.sessionId,
  });

  final String frameB64;
  final String sessionId;

  @override
  bool operator ==(Object other) {
    return other is VideoFrameAnalysisRequestDto &&
        other.frameB64 == frameB64 &&
        other.sessionId == sessionId;
  }

  @override
  int get hashCode => Object.hash(frameB64, sessionId);
}

@immutable
class AudioChunkAnalysisRequestDto {
  const AudioChunkAnalysisRequestDto({
    required this.audioB64,
    required this.sessionId,
  });

  final String audioB64;
  final String sessionId;

  @override
  bool operator ==(Object other) {
    return other is AudioChunkAnalysisRequestDto &&
        other.audioB64 == audioB64 &&
        other.sessionId == sessionId;
  }

  @override
  int get hashCode => Object.hash(audioB64, sessionId);
}
