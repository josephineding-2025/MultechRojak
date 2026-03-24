import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/models/requests.dart';
import '../../core/models/video_alert.dart';
import '../../core/state/backend_readiness_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/editorial_ui.dart';
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
  static const _stickyAlertDuration = Duration(seconds: 10);

  final List<_AlertEntry> _alerts = [];
  final _captureController = ChatCaptureController();

  _MonitorState _state = _MonitorState.idle;
  Timer? _sessionTimer;
  Timer? _visualCaptureTimer;
  Timer? _stickyAlertTimer;
  _AlertEntry? _stickyAlert;
  int _seconds = 0;
  String _statusMessage = 'Visual monitoring ready.';
  String? _errorMessage;
  String _sessionId = 'video_${DateTime.now().millisecondsSinceEpoch}';
  bool _isMuted = false;

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _visualCaptureTimer?.cancel();
    _stickyAlertTimer?.cancel();
    super.dispose();
  }

  Future<void> _startMonitoring() async {
    if (!_canUseVideoMonitoring()) {
      setState(() {
        _errorMessage = _videoCapabilityMessage();
        _state = _MonitorState.summary;
      });
      return;
    }

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
    _stickyAlertTimer?.cancel();
    _stickyAlert = null;
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
            final entry = _AlertEntry.video(alert);
            _alerts.insert(0, entry);
            _showStickyAlert(entry);
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

  void _showStickyAlert(_AlertEntry entry) {
    _stickyAlertTimer?.cancel();
    _stickyAlert = entry;
    _stickyAlertTimer = Timer(_stickyAlertDuration, () {
      if (!mounted) {
        return;
      }
      setState(() => _stickyAlert = null);
    });
  }

  void _dismissStickyAlert() {
    _stickyAlertTimer?.cancel();
    setState(() => _stickyAlert = null);
  }

  void _openStickyAlertDetails() {
    _dismissStickyAlert();
    _stopMonitoring();
  }

  void _stopMonitoring() {
    _sessionTimer?.cancel();
    _visualCaptureTimer?.cancel();
    _stickyAlertTimer?.cancel();
    setState(() {
      _stickyAlert = null;
      _state = _MonitorState.summary;
    });
  }

  void _reset() {
    _sessionTimer?.cancel();
    _visualCaptureTimer?.cancel();
    _stickyAlertTimer?.cancel();
    setState(() {
      _alerts.clear();
      _stickyAlert = null;
      _seconds = 0;
      _errorMessage = null;
      _statusMessage = 'Visual monitoring ready.';
      _state = _MonitorState.idle;
    });
  }

  bool _canUseVideoMonitoring() {
    final readiness = ref.read(backendReadinessProvider).valueOrNull;
    return readiness?.capabilityEnabled('video_frame_analysis') ?? true;
  }

  String _videoCapabilityMessage() {
    final readiness = ref.read(backendReadinessProvider).valueOrNull;
    if (readiness == null) {
      return 'Video monitoring is waiting for backend readiness.';
    }
    if (!readiness.isReachable) {
      return 'Start the backend first to monitor video calls.';
    }
    return 'Video monitoring is unavailable until OPENROUTER_API_KEY is configured.';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(backendReadinessProvider);
    final layout = _VideoMonitorLayout.fromWidth(MediaQuery.sizeOf(context).width);

    return Stack(
      children: [
        EditorialPage(
          dark: true,
          padding: layout.pagePadding,
          child: switch (_state) {
            _MonitorState.idle => _buildIdle(layout),
            _MonitorState.active => _buildActive(layout),
            _MonitorState.summary => _buildSummary(layout),
          },
        ),
        if (_stickyAlert != null && _state == _MonitorState.active)
          Positioned(
            top: 22,
            right: 18,
            left: 18,
            child: _StickyAlertCard(
              entry: _stickyAlert!,
              onDismiss: _dismissStickyAlert,
              onSeeDetails: _openStickyAlertDetails,
            ),
          ),
      ],
    );
  }

  Widget _buildIdle(_VideoMonitorLayout layout) {
    final canUseVideoMonitoring = _canUseVideoMonitoring();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EditorialEyebrow(
          label: 'ACTIVE MONITOR',
          icon: Icons.videocam,
          dark: true,
        ),
        const SizedBox(height: 18),
        Text(
          'Visuals',
          style: AppTheme.headline(
            layout.heroTitleSize,
            color: Colors.white,
            weight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Monitor the live screen every five seconds for replay artifacts, facial inconsistencies, and synthetic visual patterns.',
          style: AppTheme.body(
            14,
            color: Colors.white.withValues(alpha: 0.72),
            height: 1.55,
          ),
        ),
        const SizedBox(height: 24),
        GlassPanel(
          dark: true,
          radius: 32,
          padding: layout.panelPadding,
          child: Column(
            children: [
              SplitBackgroundFill(dark: true, height: layout.previewHeight),
              const SizedBox(height: 18),
              const Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _DarkChip(
                    icon: Icons.radar,
                    label: 'Live screen analysis',
                  ),
                  SizedBox(width: 10),
                  _DarkChip(
                    icon: Icons.lock_outline,
                    label: 'Shield active',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              GradientCtaButton(
                label: 'Start Monitoring',
                icon: Icons.shield_outlined,
                onPressed: _startMonitoring,
                enabled: canUseVideoMonitoring,
              ),
              if (!canUseVideoMonitoring) ...[
                const SizedBox(height: 12),
                Text(
                  _videoCapabilityMessage(),
                  textAlign: TextAlign.center,
                  style: AppTheme.body(
                    12,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _DarkFeatureCard(
          icon: Icons.face_outlined,
          title: 'Visual anomaly analysis',
          body:
              'Captures the screen every 5 seconds and asks the backend to score blur, replay, and face inconsistency signals.',
        ),
        const SizedBox(height: 12),
        const _DarkFeatureCard(
          icon: Icons.hearing_outlined,
          title: 'Audio pipeline next',
          body:
              'The audio endpoint exists, but native system-audio capture is still pending. The new UI shows this as a mock-first panel.',
          trailing: MockTag(label: 'Audio mock'),
        ),
      ],
    );
  }

  Widget _buildActive(_VideoMonitorLayout layout) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            const _DarkChip(
              icon: Icons.radar,
              label: 'Active Monitoring',
              pulse: true,
            ),
            _DarkChip(
              icon: Icons.schedule,
              label: _formatTime(_seconds),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatChip(label: 'Latency', value: '--ms'),
            _StatChip(label: 'Res', value: '1080p'),
            _StatChip(label: 'Shield', value: 'ON', highlight: true),
          ],
        ),
        const SizedBox(height: 16),
        // Status panel
        Container(
          width: double.infinity,
          decoration: AppTheme.darkGlass(radius: 28),
          padding: layout.compactPanelPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (layout.isCompact) ...[
                const _DarkChip(
                  icon: Icons.lock,
                  label: 'Sentinel Shield Active',
                ),
                const SizedBox(height: 10),
                const MockTag(label: 'Network mock'),
              ] else
                const Row(
                  children: [
                    Expanded(
                      child: _DarkChip(
                        icon: Icons.lock,
                        label: 'Sentinel Shield Active',
                      ),
                    ),
                    SizedBox(width: 10),
                    MockTag(label: 'Network mock'),
                  ],
                ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.insights_outlined,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: AppTheme.body(
                        12,
                        color: Colors.white.withValues(alpha: 0.74),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryFixed),
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                minHeight: 2,
              ),
              const SizedBox(height: 6),
              Text(
                'Neural processing in progress',
                style: AppTheme.label(
                  10,
                  color: Colors.white.withValues(alpha: 0.55),
                  weight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Alert area
        if (_alerts.isEmpty)
          const _DarkNoAlertCard()
        else ...[
          Text(
            'LIVE ALERT STACK',
            style: AppTheme.label(
              11,
              color: Colors.white.withValues(alpha: 0.65),
              weight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ..._alerts.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AlertCard(entry: entry),
            ),
          ),
        ],
        const SizedBox(height: 14),
        // Mock audio panel
        const _MockAudioAlertCard(),
        const SizedBox(height: 10),
        // Mock network panel
        _MockNetworkPanel(seconds: _seconds),
        const SizedBox(height: 18),
        // Controls
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(() => _isMuted = !_isMuted),
              style: OutlinedButton.styleFrom(
                foregroundColor: _isMuted ? AppTheme.error : Colors.white,
                side: BorderSide(
                  color: _isMuted
                      ? AppTheme.error
                      : Colors.white.withValues(alpha: 0.3),
                ),
              ),
              icon: Icon(_isMuted ? Icons.mic_off : Icons.mic_none),
              label: Text(_isMuted ? 'Unmute' : 'Mute'),
            ),
            FilledButton.icon(
              onPressed: _stopMonitoring,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Stop Monitoring'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummary(_VideoMonitorLayout layout) {
    final highestSeverity = _alerts.isEmpty
        ? 'LOW'
        : _alerts.map((entry) => entry.severity).reduce(_maxSeverity);
    final summaryColor = _alerts.isEmpty
        ? AppTheme.riskLevelColor('LOW')
        : AppTheme.severityColor(highestSeverity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EditorialEyebrow(
          label: 'SESSION SUMMARY',
          icon: Icons.summarize_outlined,
          dark: true,
        ),
        const SizedBox(height: 18),
        Text(
          'Call Summary',
          style: AppTheme.headline(
            layout.summaryTitleSize,
            color: Colors.white,
            weight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 18),
        GlassPanel(
          dark: true,
          padding: layout.panelPadding,
          child: layout.isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: MetricRing(
                        score: (_alerts.length * 20).clamp(0, 100),
                        label: 'ALERT LOAD',
                        color: summaryColor,
                        size: 104,
                        dark: true,
                        trackColor: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _alerts.isEmpty
                          ? 'No visual alerts were triggered.'
                          : '${_alerts.length} visual alert${_alerts.length == 1 ? '' : 's'} were triggered.',
                      style: AppTheme.headline(
                        18,
                        color: Colors.white,
                        weight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage,
                      style: AppTheme.body(
                        12,
                        color: Colors.white.withValues(alpha: 0.72),
                        height: 1.5,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    MetricRing(
                      score: (_alerts.length * 20).clamp(0, 100),
                      label: 'ALERT LOAD',
                      color: summaryColor,
                      size: 104,
                      dark: true,
                      trackColor: Colors.white.withValues(alpha: 0.1),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _alerts.isEmpty
                                ? 'No visual alerts were triggered.'
                                : '${_alerts.length} visual alert${_alerts.length == 1 ? '' : 's'} were triggered.',
                            style: AppTheme.headline(
                              20,
                              color: Colors.white,
                              weight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _statusMessage,
                            style: AppTheme.body(
                              12,
                              color: Colors.white.withValues(alpha: 0.72),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          TonalPanel(
            color: AppTheme.error.withValues(alpha: 0.14),
            child: Text(
              _errorMessage!,
              style: AppTheme.body(12, color: Colors.white),
            ),
          ),
        ],
        if (_alerts.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'SESSION ALERTS',
            style: AppTheme.label(
              11,
              color: Colors.white.withValues(alpha: 0.64),
              weight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ..._alerts.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AlertCard(entry: entry),
            ),
          ),
        ],
        const SizedBox(height: 18),
        OutlinedButton(
          onPressed: _reset,
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
          child: const Text('New Monitoring Session'),
        ),
      ],
    );
  }

  String _maxSeverity(String left, String right) {
    const rank = {
      'CRITICAL': 4,
      'HIGH': 3,
      'MEDIUM': 2,
      'LOW': 1,
    };
    final leftScore = rank[left.toUpperCase()] ?? 0;
    final rightScore = rank[right.toUpperCase()] ?? 0;
    return leftScore >= rightScore ? left : right;
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }
}

class _VideoMonitorLayout {
  const _VideoMonitorLayout._(this.width);

  factory _VideoMonitorLayout.fromWidth(double width) {
    return _VideoMonitorLayout._(width);
  }

  final double width;

  bool get isCompact => width < 320;
  bool get isNarrow => width < 420;

  double get heroTitleSize => isCompact ? 32 : (isNarrow ? 40 : 46);
  double get summaryTitleSize => isCompact ? 30 : 36;
  double get previewHeight => isCompact ? 160 : (isNarrow ? 190 : 220);

  EdgeInsets get pagePadding => EdgeInsets.fromLTRB(
        isCompact ? 16 : 20,
        isCompact ? 22 : 28,
        isCompact ? 16 : 20,
        isCompact ? 20 : 28,
      );

  EdgeInsets get panelPadding => EdgeInsets.all(isCompact ? 18 : 24);
  EdgeInsets get compactPanelPadding => EdgeInsets.all(isCompact ? 16 : 18);
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

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, this.highlight = false});
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.primaryFixed.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        '$label: $value',
        style: AppTheme.label(
          10,
          color: Colors.white.withValues(alpha: 0.88),
          weight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}


class _DarkChip extends StatelessWidget {
  const _DarkChip({
    required this.icon,
    required this.label,
    this.pulse = false,
  });

  final IconData icon;
  final String label;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pulse) ...[
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppTheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
          ] else ...[
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.label(
                10,
                color: Colors.white,
                weight: FontWeight.w800,
                letterSpacing: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkFeatureCard extends StatelessWidget {
  const _DarkFeatureCard({
    required this.icon,
    required this.title,
    required this.body,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      dark: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = trailing != null && constraints.maxWidth < 220;
                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTheme.headline(
                              16,
                              color: Colors.white,
                              weight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          trailing!,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: AppTheme.headline(
                              16,
                              color: Colors.white,
                              weight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (trailing != null) trailing!,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: AppTheme.body(
                    12,
                    color: Colors.white.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkNoAlertCard extends StatelessWidget {
  const _DarkNoAlertCard();

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      dark: true,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: AppTheme.successContainer,
              size: 30,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No visual alerts detected',
            style: AppTheme.headline(
              18,
              color: Colors.white,
              weight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Monitoring continues in the background with the current scan cadence.',
            textAlign: TextAlign.center,
            style: AppTheme.body(
              12,
              color: Colors.white.withValues(alpha: 0.68),
              height: 1.5,
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
    final color = AppTheme.severityColor(entry.severity);
    return GlassPanel(
      dark: true,
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.face_outlined, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Visual Alert',
                      style: AppTheme.headline(
                        16,
                        color: Colors.white,
                        weight: FontWeight.w800,
                      ),
                    ),
                    RiskBadge(
                      label: entry.severity,
                      color: color,
                      background: color.withValues(alpha: 0.16),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  entry.reason,
                  style: AppTheme.body(
                    12,
                    color: Colors.white.withValues(alpha: 0.72),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MockAudioAlertCard extends StatelessWidget {
  const _MockAudioAlertCard();

  @override
  Widget build(BuildContext context) {
    return TonalPanel(
      color: Colors.white.withValues(alpha: 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MockTag(label: 'Audio mock'),
          const SizedBox(height: 10),
          Text(
            'Audio Alert',
            style: AppTheme.headline(
              16,
              color: Colors.white,
              weight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Urgent money request and pressured transfer language will appear here once the native audio bridge is wired.',
            style: AppTheme.body(
              11,
              color: Colors.white.withValues(alpha: 0.66),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _MockNetworkPanel extends StatelessWidget {
  const _MockNetworkPanel({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final progress = ((seconds % 100) / 100).clamp(0.2, 0.86);
    return TonalPanel(
      color: Colors.white.withValues(alpha: 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MockTag(label: 'Network mock'),
          const SizedBox(height: 10),
          Text(
            'Analysis Engine',
            style: AppTheme.headline(
              16,
              color: Colors.white,
              weight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Neural processing in progress...',
            style: AppTheme.body(
              11,
              color: Colors.white.withValues(alpha: 0.66),
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyAlertCard extends StatelessWidget {
  const _StickyAlertCard({
    required this.entry,
    required this.onDismiss,
    required this.onSeeDetails,
  });

  final _AlertEntry entry;
  final VoidCallback onDismiss;
  final VoidCallback onSeeDetails;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.severityColor(entry.severity);

    return Material(
      color: Colors.transparent,
      child: GlassPanel(
        dark: true,
        radius: 26,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Red Flag Detected',
                    style: AppTheme.headline(
                      16,
                      color: Colors.white,
                      weight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onDismiss,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 18, color: Colors.white),
                ),
              ],
            ),
            Text(
              entry.reason,
              style: AppTheme.body(
                12,
                color: Colors.white.withValues(alpha: 0.74),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              overflowSpacing: 8,
              children: [
                TextButton(
                  onPressed: onDismiss,
                  child: const Text('Dismiss'),
                ),
                FilledButton(
                  onPressed: onSeeDetails,
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('See Details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
