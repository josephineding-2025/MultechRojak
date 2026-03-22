// Owner: Member 1
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/background_check_result.dart';
import 'background_check_service.dart';

/// Call this provider with the check parameters to trigger a background check.
/// Usage: ref.read(backgroundCheckProvider({'username': 'john', 'platform': 'Telegram'}).future)
final backgroundCheckProvider = FutureProvider.family<BackgroundCheckResult, Map<String, String>>(
  (ref, params) async {
    final service = BackgroundCheckService();
    return service.runBackgroundCheck(
      username: params['username'] ?? '',
      platform: params['platform'] ?? '',
      phone: params['phone'],
      photoB64: params['photo_b64'],
    );
  },
);
