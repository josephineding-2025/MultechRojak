// Owner: Member 2
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/video_alert.dart';
import '../../core/theme/app_theme.dart';

enum _MonitorState { idle, active }

class VideoMonitorScreen extends ConsumerStatefulWidget {
  const VideoMonitorScreen({super.key});

  @override
  ConsumerState<VideoMonitorScreen> createState() => _VideoMonitorScreenState();
}

class _VideoMonitorScreenState extends ConsumerState<VideoMonitorScreen> {
  _MonitorState _state = _MonitorState.idle;
  final List<_AlertEntry> _alerts = [];
  int _seconds = 0;

  void _startMonitoring() =>
      setState(() => _state = _MonitorState.active);

  void _stopMonitoring() =>
      setState(() => _state = _MonitorState.idle);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: switch (_state) {
        _MonitorState.idle => _buildIdle(),
        _MonitorState.active => _buildActive(),
      },
    );
  }

  // ── Idle ────────────────────────────────────────────────────────────────

  Widget _buildIdle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.videocam_outlined,
              size: 18, color: AppTheme.primaryContainer),
          const SizedBox(width: 8),
          Text('Video Call Monitor', style: AppTheme.headline(15)),
        ]),
        const SizedBox(height: 4),
        Text(
          'Passively monitors your video call for deepfake signals and suspicious audio patterns.',
          style: AppTheme.body(11, color: AppTheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        _GradientButton(
          label: 'Start Monitoring',
          icon: Icons.shield_outlined,
          onPressed: _startMonitoring,
        ),
        const SizedBox(height: 20),
        Text('DETECTION CAPABILITIES',
            style: AppTheme.label(9, color: AppTheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        _FeatureCard(
          icon: Icons.face_outlined,
          title: 'Face consistency analysis',
          body:
              'Detects frame-to-frame inconsistencies that may indicate a deepfake or pre-recorded video.',
        ),
        const SizedBox(height: 8),
        _FeatureCard(
          icon: Icons.hearing_outlined,
          title: 'Live audio detection',
          body:
              'Transcribes and analyzes speech for money requests, urgency language, and script patterns.',
        ),
      ],
    );
  }

  // ── Active ───────────────────────────────────────────────────────────────

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
              Text('Sentinel Shield Active',
                  style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              const Spacer(),
              Text(_formatTime(_seconds),
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.8))),
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
                const Icon(Icons.check_circle_outline,
                    color: Color(0xFF2E7D32), size: 28),
                const SizedBox(height: 6),
                Text('No alerts detected',
                    style: AppTheme.body(12,
                        color: const Color(0xFF2E7D32))),
                const SizedBox(height: 2),
                Text('Monitoring in progress...',
                    style: AppTheme.label(10)),
              ],
            ),
          )
        else ...[
          Text('ALERTS (${_alerts.length})',
              style: AppTheme.label(9, color: AppTheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          ..._alerts.map((a) => _AlertCard(entry: a)),
        ],
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _stopMonitoring,
          child: const Text('Stop Monitoring'),
        ),
      ],
    );
  }

  String _formatTime(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}

// ── Alert entry model ─────────────────────────────────────────────────────────

class _AlertEntry {
  final String type; // 'video' | 'audio'
  final VideoAlert? videoAlert;
  final AudioAlert? audioAlert;
  final DateTime time;
  _AlertEntry.video(this.videoAlert)
      : type = 'video',
        audioAlert = null,
        time = DateTime.now();
  _AlertEntry.audio(this.audioAlert)
      : type = 'audio',
        videoAlert = null,
        time = DateTime.now();

  String get reason => videoAlert?.reason ?? audioAlert?.reason ?? '';
  String get severity => videoAlert?.severity ?? audioAlert?.severity ?? '';
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _GradientButton(
      {required this.label, required this.icon, required this.onPressed});

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
            Text(label,
                style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _FeatureCard(
      {required this.icon, required this.title, required this.body});

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
                Text(body,
                    style: AppTheme.body(11,
                        color: AppTheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final _AlertEntry entry;
  const _AlertCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isHigh =
        entry.severity == 'critical' || entry.severity == 'high';
    final bg = isHigh ? AppTheme.errorContainer : const Color(0xFFFFF8E1);
    final color = isHigh ? AppTheme.error : const Color(0xFFF57F17);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            entry.type == 'audio'
                ? Icons.hearing_outlined
                : Icons.videocam_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
              child: Text(entry.reason, style: AppTheme.body(11))),
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10)),
            child: Text(entry.severity.toUpperCase(),
                style: AppTheme.label(9, color: color)),
          ),
        ],
      ),
    );
  }
}
