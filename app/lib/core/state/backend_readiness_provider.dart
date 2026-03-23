import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/backend_readiness.dart';

final backendReadinessRefreshProvider = StateProvider<int>((ref) => 0);

final backendReadinessProvider = FutureProvider<BackendReadiness>((ref) async {
  ref.watch(backendReadinessRefreshProvider);
  return ApiClient.instance.fetchBackendReadiness();
});
