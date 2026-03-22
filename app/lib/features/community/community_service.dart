// Owner: Member 3
import '../../core/api/api_client.dart';
import '../../core/models/community_flag.dart';

class CommunityService {
  final _client = ApiClient.instance;

  /// Check if a profile appears in the community database.
  Future<ProfileCheckResult> checkProfile({
    String? handle,
    String? phone,
    String? photoHash,
  }) async {
    final response = await _client.dio.get(
      '/check-profile',
      queryParameters: {
        if (handle != null) 'handle': handle,
        if (phone != null) 'phone': phone,
        if (photoHash != null) 'photo_hash': photoHash,
      },
    );
    return ProfileCheckResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// Submit a community flag for a scammer.
  /// TODO (Member 3): Validate that user has completed a scan with risk_score >= Medium
  /// before allowing submission (see SPEC.md Section 4.4 submission rules).
  Future<FlagScammerResult> flagScammer(Map<String, dynamic> params) async {
    final response = await _client.dio.post('/flag-scammer', data: params);
    return FlagScammerResult.fromJson(response.data as Map<String, dynamic>);
  }
}
