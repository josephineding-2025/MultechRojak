// Owner: Member 1
import '../../core/api/api_client.dart';
import '../../core/models/background_check_result.dart';

class BackgroundCheckService {
  final _client = ApiClient.instance;

  /// Run a background check on a profile.
  /// TODO (Member 1): This calls the mock backend — no changes needed here.
  /// Implement the real pipeline in backend/services/osint/.
  Future<BackgroundCheckResult> runBackgroundCheck({
    required String username,
    required String platform,
    String? phone,
    String? photoB64,
  }) async {
    final response = await _client.dio.post(
      '/background-check',
      data: {
        'username': username,
        'platform': platform,
        if (phone != null) 'phone': phone,
        if (photoB64 != null) 'photo_b64': photoB64,
      },
    );
    return BackgroundCheckResult.fromJson(
      response.data as Map<String, dynamic>,
    );
  }
}
