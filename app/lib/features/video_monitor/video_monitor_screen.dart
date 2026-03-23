// Owner: Member 2
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_error.dart';
import '../../core/models/requests.dart';
import '../../core/models/video_alert.dart';
import '../../core/theme/app_theme.dart';
import '../chat_monitor/chat_capture_controller.dart';
import 'video_monitor_provider.dart';

enum _MonitorState { idle, active, summary }

class VideoMonitorScreen extends ConsumerStatefulWidget {
  const VideoMonitorScreen({super.key});

  @override
  ConsumerState<VideoMonitorScreen> createState() => _VideoMonitorScreenState();
}

class _VideoMonitorScreenState extends ConsumerState<VideoMonitorScreen> {
  static const _visualScanInterval = Duration(seconds: 5);

  final List<_AlertEntry> _alerts = [];
  final _captureController = ChatCaptureController();

  _MonitorState _state = _MonitorState.idle;
  Timer? _sessionTimer;
  Timer? _visualCaptureTimer;
  int _seconds = 0;
  String _statusMessage = 'Visual monitoring ready.';
  String? _errorMessage;
  String _sessionId = 'video_${DateTime.now().millisecondsSinceEpoch}';

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _visualCaptureTimer?.cancel();
    super.dispose();
  }

  Future<void> _startMonitoring() async {
    final hasAccess = await _captureController.ensureCaptureAccess();
    if (!hasAccess) {
      setState(() {
        _errorMessage =
            'Screen capture permission is required before video monitoring can start.';
        _state = _MonitorState.summary;
      });
      return;
    }

    _sessionTimer?.cancel();
    _visualCaptureTimer?.cancel();
    _sessionId = 'video_${DateTime.now().millisecondsSinceEpoch}';
    _captureController.reset();
    setState(() {
      _alerts.clear();
      _seconds = 0;
      _errorMessage = null;
      _statusMessage =
          'Visual monitoring is active. Audio capture setup is still pending.';
      _state = _MonitorState.active;
    });

    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _state != _MonitorState.active) {
        return;
      }
      setState(() => _seconds += 1);
    });

    _visualCaptureTimer = Timer.periodic(_visualScanInterval, (_) async {
      if (!mounted || _state != _MonitorState.active) {
        return;
      }

      try {
        final frame = await _captureController.captureCurrentFrame();
        if (frame == null) {
          return;
        }

        final alert = await ref.read(
          videoFrameProvider(
            VideoFrameAnalysisRequestDto(
              frameB64: frame,
              sessionId: _sessionId,
            ),
          ).future,
        );
        if (!mounted) {
          return;
        }

        setState(() {
          _statusMessage = alert.alert
              ? 'Suspicious visual pattern detected.'
              : 'No suspicious visual pattern detected in the latest scan.';
          if (alert.alert) {
            _alerts.insert(0, _AlertEntry.video(alert));
          }
        });
      } catch (error) {
        _sessionTimer?.cancel();
        _visualCaptureTimer?.cancel();
        if (!mounted) {
          return;
        }
        setState(() {
          _errorMessage = formatApiError(
            error,
            fallbackMessage: 'Visual monitoring failed. Check the backend logs.',
          );
          _statusMessage = 'Monitoring stopped because the last scan failed.';
          _state = _MonitorState.summary;
        });
      }
    });
  }

  void _stopMonitoring() {
    _sessionTimer?.cancel();
    _visualCaptureTimer?.cancel();
    setState(() => _state = _MonitorState.summary);
  }

  void _reset() {
    _sessionTimer?.cancel();
    _visualCaptureTimer?.cancel();
    setState(() {
      _alerts.clear();
      _seconds = 0;
      _errorMessage = null;
      _statusMessage = 'Visual monitoring ready.';
      _state = _MonitorState.idle;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: switch (_state) {
        _MonitorState.idle => _buildIdle(),
        _MonitorState.active => _buildActive(),
        _MonitorState.summary => _buildSummary(),
      },
    );
  }

  Widget _buildIdle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Row(children: [
          const Icon(
            Icons.videocam_outlined,
            size: 18,
            color: AppTheme.primaryContainer,
          ),
          const SizedBox(width: 8),
          Text('Video Call Monitor', style: AppTheme.headline(15)),
        ]),
        const SizedBox(height: 4),
        Text(
          'Passively monitors your video call for deepfake signals. Visual scanning is live; audio capture remains the next platform-specific step.',
          style: AppTheme.body(11, color: AppTheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        _GradientButton(
          label: 'Start Monitoring',
          icon: Icons.shield_outlined,
          onPressed: _startMonitoring,
        ),
        const SizedBox(height: 20),
        Text(
          'DETECTION CAPABILITIES',
          style: AppTheme.label(9, color: AppTheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        const _FeatureCard(
          icon: Icons.face_outlined,
          title: 'Visual anomaly analysis',
          body:
              'Captures a full-screen frame every 5 seconds and asks the backend to look for face inconsistency, blur, or replay artifacts.',
        ),
        const SizedBox(height: 8),
        const _FeatureCard(
          icon: Icons.hearing_outlined,
          title: 'Audio pipeline next',
          body:
              'The backend endpoint is ready, but native macOS system-audio capture still needs a BlackHole-backed bridge.',
        ),
      ],
    );
  }

  Widget _buildActive() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: AppTheme.gradientBox(radius: 10),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, color: Colors.white, size: 15),
              const SizedBox(width: 6),
              Text(
                'Sentinel Shield Active',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                _formatTime(_seconds),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: AppTheme.tonalSection(),
          child: Row(
            children: [
              const Icon(
                Icons.radar,
                size: 14,
                color: AppTheme.primaryContainer,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _statusMessage,
                  style: AppTheme.body(10, color: AppTheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_alerts.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.tonalSection(),
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF2E7D32),
                  size: 28,
                ),
                const SizedBox(height: 6),
                Text(
                  'No visual alerts detected',
                  style: AppTheme.body(12, color: const Color(0xFF2E7D32)),
                ),
                const SizedBox(height: 2),
                Text('Monitoring in progress...', style: AppTheme.label(10)),
              ],
            ),
          )
        else ...[
          Text(
            'ALERTS (${_alerts.length})',
            style: AppTheme.label(9, color: AppTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          ..._alerts.map((entry) => _AlertCard(entry: entry)),
        ],
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _stopMonitoring,
          child: const Text('Stop Monitoring'),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.summarize_outlined,
              size: 18,
              color: AppTheme.primaryContainer,
            ),
            const SizedBox(width: 8),
            Text('Call Summary', style: AppTheme.headline(15)),
          ],
        ),
        const SizedBox(height: 8),
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _errorMessage!,
              style: AppTheme.body(11, color: AppTheme.error),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Container(
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.surfaceCard(),
          child: Row(
            children: [
              Text(
                '${_alerts.length}',
                style: GoogleFonts.manrope(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: _alerts.isEmpty
                      ? const Color(0xFF2E7D32)
                      : AppTheme.error,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _alerts.isEmpty
                      ? 'No visual alerts were triggered during this session.'
                      : 'Visual alerts were triggered during this session.',
                  style: AppTheme.body(11, color: AppTheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        if (_alerts.isNotEmpty) ...[
          const SizedBox(height: 10),
          ..._alerts.map((entry) => _AlertCard(entry: entry)),
        ],
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _reset,
          child: const Text('New Monitoring Session'),
        ),
      ],
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }
}

class _AlertEntry {
  _AlertEntry.video(this.videoAlert)
      : type = 'video',
        audioAlert = null,
        time = DateTime.now();

  final String type;
  final VideoAlert? videoAlert;
  final AudioAlert? audioAlert;
  final DateTime time;

  String get reason => videoAlert?.reason ?? audioAlert?.reason ?? '';
  String get severity => videoAlert?.severity ?? audioAlert?.severity ?? '';
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 46,
        decoration: AppTheme.gradientBox(radius: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.tonalSection(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.headline(12)),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: AppTheme.body(11, color: AppTheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.entry});

  final _AlertEntry entry;

  @override
  Widget build(BuildContext context) {
    final isHigh =
        entry.severity == 'critical' || entry.severity == 'high';
    final background =
        isHigh ? AppTheme.errorContainer : const Color(0xFFFFF8E1);
    final color = isHigh ? AppTheme.error : const Color(0xFFF57F17);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.videocam_outlined, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(entry.reason, style: AppTheme.body(11))),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              entry.severity.toUpperCase(),
              style: AppTheme.label(9, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
