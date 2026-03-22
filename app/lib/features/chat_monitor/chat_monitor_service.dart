// Owner: Member 2
import '../../core/api/api_client.dart';
import '../../core/models/risk_report.dart';

class ChatMonitorService {
  final _client = ApiClient.instance;

  /// Analyze captured chat frames.
  /// TODO (Member 2): Add screen capture logic — collect frames via screen_capturer,
  /// deduplicate, convert to base64, then pass to this method.
  Future<RiskReport> analyzeChat({
    required String platform,
    required String sessionId,
    List<String> frames = const [],
  }) async {
    final response = await _client.dio.post(
      '/analyze-chat',
      data: {
        'frames': frames,
        'platform': platform,
        'session_id': sessionId,
      },
    );
    return RiskReport.fromJson(response.data as Map<String, dynamic>);
  }
}
