// Owner: Member 2
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/video_alert.dart';
import 'video_monitor_service.dart';

/// Analyze a single video frame.
final videoFrameProvider = FutureProvider.family<VideoAlert, Map<String, String>>(
  (ref, params) async {
    final service = VideoMonitorService();
    return service.analyzeFrame(
      frameB64: params['frame'] ?? '',
      sessionId: params['session_id'] ?? '',
    );
  },
);

/// Analyze an audio chunk from a live call.
final audioChunkProvider = FutureProvider.family<AudioAlert, Map<String, String>>(
  (ref, params) async {
    final service = VideoMonitorService();
    return service.analyzeAudioChunk(
      audioB64: params['audio_b64'] ?? '',
      sessionId: params['session_id'] ?? '',
    );
  },
);
