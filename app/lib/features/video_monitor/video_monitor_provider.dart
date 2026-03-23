// Owner: Member 2
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/requests.dart';
import '../../core/models/video_alert.dart';
import 'video_monitor_service.dart';

/// Analyze a single video frame.
final videoFrameProvider =
    FutureProvider.family<VideoAlert, VideoFrameAnalysisRequestDto>(
  (ref, request) async {
    final service = VideoMonitorService();
    return service.analyzeFrame(request);
  },
);

/// Analyze an audio chunk from a live call.
final audioChunkProvider =
    FutureProvider.family<AudioAlert, AudioChunkAnalysisRequestDto>(
  (ref, request) async {
    final service = VideoMonitorService();
    return service.analyzeAudioChunk(request);
  },
);
