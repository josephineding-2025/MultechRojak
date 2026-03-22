// Owner: Member 2
import '../../core/api/api_client.dart';
import '../../core/models/video_alert.dart';

class VideoMonitorService {
  final _client = ApiClient.instance;

  /// Analyze a single video call frame.
  /// TODO (Member 2): Capture frames via screen_capturer and pass base64 here.
  Future<VideoAlert> analyzeFrame({
    required String frameB64,
    required String sessionId,
  }) async {
    final response = await _client.dio.post(
      '/analyze-video-frame',
      data: {'frame': frameB64, 'session_id': sessionId},
    );
    return VideoAlert.fromJson(response.data as Map<String, dynamic>);
  }

  /// Analyze a transcribed audio chunk from a live call.
  /// TODO (Member 2): Capture system audio and pass base64 here.
  Future<AudioAlert> analyzeAudioChunk({
    required String audioB64,
    required String sessionId,
  }) async {
    final response = await _client.dio.post(
      '/analyze-audio-chunk',
      data: {'audio_b64': audioB64, 'session_id': sessionId},
    );
    return AudioAlert.fromJson(response.data as Map<String, dynamic>);
  }
}
