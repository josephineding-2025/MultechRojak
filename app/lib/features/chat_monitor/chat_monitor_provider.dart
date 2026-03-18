// Owner: Member 2
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/risk_report.dart';
import 'chat_monitor_service.dart';

/// Call this provider with a list of base64 frames + platform name.
/// Usage: ref.read(chatAnalysisProvider({'platform': 'WhatsApp', 'session_id': uuid}).future)
/// The service reads captured frames internally.
final chatAnalysisProvider = FutureProvider.family<RiskReport, Map<String, String>>(
  (ref, params) async {
    final service = ChatMonitorService();
    return service.analyzeChat(
      platform: params['platform'] ?? 'Unknown',
      sessionId: params['session_id'] ?? '',
    );
  },
);
