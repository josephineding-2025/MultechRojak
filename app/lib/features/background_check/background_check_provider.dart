// Owner: Member 1
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/background_check_result.dart';
import '../../core/models/requests.dart';
import 'background_check_service.dart';

final backgroundCheckProvider =
    FutureProvider.family<BackgroundCheckResult, BackgroundCheckRequestDto>(
  (ref, request) async {
    final service = BackgroundCheckService();
    return service.runBackgroundCheck(request);
  },
);
