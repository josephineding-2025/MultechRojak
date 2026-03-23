// Owner: Member 2
import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/models/requests.dart';
import '../../core/models/risk_report.dart';

class ChatMonitorService {
  final _client = ApiClient.instance;
  static const _analysisTimeout = Duration(minutes: 2);

  /// Analyze captured chat frames.
  Future<RiskReport> analyzeChat(ChatAnalysisRequestDto request) async {
    final response = await _client.dio.post(
      '/analyze-chat',
      data: {
        'frames': request.frames,
        'platform': request.platform,
        'session_id': request.sessionId,
      },
      options: Options(
        receiveTimeout: _analysisTimeout,
        sendTimeout: _analysisTimeout,
      ),
    );
    return RiskReport.fromJson(response.data as Map<String, dynamic>);
  }
}
