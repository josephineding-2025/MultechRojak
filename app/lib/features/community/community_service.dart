// Owner: Member 3
import '../../core/api/api_client.dart';
import '../../core/models/community_flag.dart';
import '../../core/models/requests.dart';

class CommunityService {
  final _client = ApiClient.instance;

  /// Check if a profile appears in the community database.
  Future<ProfileCheckResult> checkProfile(
    CommunityProfileLookupDto lookup,
  ) async {
    final response = await _client.dio.get(
      '/check-profile',
      queryParameters: lookup.toQueryParameters(),
    );
    return ProfileCheckResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<FlagScammerResult> flagScammer(
    CommunityFlagRequestDto request,
  ) async {
    final response =
        await _client.dio.post('/flag-scammer', data: request.toJson());
    return FlagScammerResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<CommunityFeedEntry>> getFeed({int limit = 10}) async {
    final response = await _client.dio.get(
      '/community/feed',
      queryParameters: {'limit': limit},
    );
    return (response.data as List)
        .map((e) => CommunityFeedEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
