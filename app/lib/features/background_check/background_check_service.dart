// Owner: Member 1
import '../../core/api/api_client.dart';
import '../../core/models/background_check_result.dart';
import '../../core/models/requests.dart';

class BackgroundCheckService {
  final _client = ApiClient.instance;

  /// Run a background check on a profile.
  Future<BackgroundCheckResult> runBackgroundCheck(
    BackgroundCheckRequestDto request,
  ) async {
    final response = await _client.dio.post(
      '/background-check',
      data: {
        'username': request.username,
        'platform': request.platform,
        if (request.phone != null) 'phone': request.phone,
        if (request.photoB64 != null) 'photo_b64': request.photoB64,
        if (request.profileUrl != null) 'profile_url': request.profileUrl,
      },
    );
    return BackgroundCheckResult.fromJson(
      response.data as Map<String, dynamic>,
    );
  }
}
