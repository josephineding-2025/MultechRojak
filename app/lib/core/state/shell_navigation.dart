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
  });

  final int launchId;
  final CommunityLaunchMode mode;
  final String? platform;
  final String? handle;
  final String? phone;
  final String? photoHash;
}

final shellTabProvider = StateProvider<ShellTab>((ref) => ShellTab.monitor);

final communityLaunchIntentProvider =
    StateProvider<CommunityLaunchIntent?>((ref) => null);
