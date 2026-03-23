// Owner: Member 2
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/requests.dart';
import '../../core/models/risk_report.dart';
import 'chat_monitor_service.dart';

final chatAnalysisProvider =
    FutureProvider.family<RiskReport, ChatAnalysisRequestDto>(
  (ref, request) async {
    final service = ChatMonitorService();
    return service.analyzeChat(request);
  },
);
