// Owner: Member 3
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/community_flag.dart';
import '../../core/models/requests.dart';
import 'community_service.dart';

final profileCheckProvider =
    FutureProvider.family<ProfileCheckResult, CommunityProfileLookupDto>(
  (ref, lookup) async {
    final service = CommunityService();
    return service.checkProfile(lookup);
  },
);

final flagScammerProvider =
    FutureProvider.family<FlagScammerResult, CommunityFlagRequestDto>(
  (ref, request) async {
    final service = CommunityService();
    return service.flagScammer(request);
  },
);
