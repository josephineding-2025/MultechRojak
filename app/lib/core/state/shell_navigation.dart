import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ShellTab { monitor, visuals, osint, circle }

enum CommunityLaunchMode { check, flag }

@immutable
class CommunityLaunchIntent {
  const CommunityLaunchIntent({
    required this.launchId,
    required this.mode,
    this.platform,
    this.handle,
    this.phone,
    this.photoHash,
    this.sourceType,
    this.sourceRiskLevel,
    this.sourceSessionId,
  });

  final int launchId;
  final CommunityLaunchMode mode;
  final String? platform;
  final String? handle;
  final String? phone;
  final String? photoHash;
  // Eligibility carried inline so the community screen doesn't need a disk read
  final String? sourceType;
  final String? sourceRiskLevel;
  final String? sourceSessionId;
}

final shellTabProvider = StateProvider<ShellTab>((ref) => ShellTab.monitor);

final communityLaunchIntentProvider =
    StateProvider<CommunityLaunchIntent?>((ref) => null);
