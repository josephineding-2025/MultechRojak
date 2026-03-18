// Owner: Member 3
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/community_flag.dart';
import 'community_service.dart';

/// Check if a profile is in the community database.
final profileCheckProvider = FutureProvider.family<ProfileCheckResult, Map<String, String>>(
  (ref, params) async {
    final service = CommunityService();
    return service.checkProfile(
      handle: params['handle'],
      phone: params['phone'],
      photoHash: params['photo_hash'],
    );
  },
);

/// Flag a scammer profile.
final flagScammerProvider = FutureProvider.family<FlagScammerResult, Map<String, dynamic>>(
  (ref, params) async {
    final service = CommunityService();
    return service.flagScammer(params);
  },
);
