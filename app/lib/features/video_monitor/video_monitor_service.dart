// Owner: Member 2
import '../../core/api/api_client.dart';
import '../../core/models/requests.dart';
import '../../core/models/video_alert.dart';

class VideoMonitorService {
  final _client = ApiClient.instance;

  /// Analyze a single video call frame.
  Future<VideoAlert> analyzeFrame(VideoFrameAnalysisRequestDto request) async {
    final response = await _client.dio.post(
      '/analyze-video-frame',
      data: {'frame': request.frameB64, 'session_id': request.sessionId},
    );
    return VideoAlert.fromJson(response.data as Map<String, dynamic>);
  }

  /// Analyze a transcribed audio chunk from a live call.
  Future<AudioAlert> analyzeAudioChunk(
    AudioChunkAnalysisRequestDto request,
  ) async {
    final response = await _client.dio.post(
      '/analyze-audio-chunk',
      data: {'audio_b64': request.audioB64, 'session_id': request.sessionId},
    );
    return AudioAlert.fromJson(response.data as Map<String, dynamic>);
  }
}
