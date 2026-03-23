import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/models/app_state.dart';
import '../../core/models/requests.dart';
import '../../core/models/risk_report.dart';
import '../../core/state/backend_readiness_provider.dart';
import '../../core/state/shell_navigation.dart';
import '../../core/storage/local_app_state_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/editorial_ui.dart';
import '../background_check/background_check_utils.dart';
import 'chat_capture_controller.dart';
import 'chat_monitor_provider.dart';

enum _ScanState { idle, scanning, analyzing, report, error }

class ChatMonitorScreen extends ConsumerStatefulWidget {
  const ChatMonitorScreen({super.key});

  @override
  ConsumerState<ChatMonitorScreen> createState() => _ChatMonitorScreenState();
}

class _ChatMonitorScreenState extends ConsumerState<ChatMonitorScreen> {
  static const _captureInterval = Duration(milliseconds: 500);
  static const _maxFramesForAnalysis = 24;
  static const _platforms = [
    'WhatsApp',
    'Telegram',
    'Instagram',
    'Dating App',
    'Other',
  ];

  _ScanState _state = _ScanState.idle;
  int _frameCount = 0;
  RiskReport? _report;
  String? _errorMessage;
  String _selectedPlatform = _platforms.first;
  Timer? _captureTimer;
  final _captureController = ChatCaptureController();

  String _sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
  final List<String> _frames = [];

  @override
  void dispose() {
    _captureTimer?.cancel();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (!_canUseChatAnalysis()) {
      setState(() {
        _errorMessage = _chatCapabilityMessage();
        _state = _ScanState.error;
      });
      return;
    }

    final hasAccess = await _captureController.ensureCaptureAccess();
    if (!hasAccess) {
      setState(() {
        _errorMessage =
            'Screen capture permission is required before scanning chats.';
        _state = _ScanState.error;
      });
      return;
    }

    _captureTimer?.cancel();
    _captureController.reset();
    _sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _state = _ScanState.scanning;
      _frameCount = 0;
      _errorMessage = null;
      _report = null;
      _frames.clear();
    });

    _captureTimer = Timer.periodic(_captureInterval, (_) async {
      if (!mounted || _state != _ScanState.scanning) {
        return;
      }

      try {
        final frame = await _captureController.captureChangedFrame();
        if (frame == null) {
          return;
        }

        setState(() {
          _frames.add(frame);
          _frameCount = _frames.length;
        });
      } catch (error) {
        _captureTimer?.cancel();
        if (!mounted) {
          return;
        }
        setState(() {
          _errorMessage = 'Failed to capture the screen: $error';
          _state = _ScanState.error;
        });
      }
    });
  }

  Future<void> _analyze() async {
    if (!_canUseChatAnalysis()) {
      setState(() {
        _errorMessage = _chatCapabilityMessage();
        _state = _ScanState.error;
      });
      return;
    }

    _captureTimer?.cancel();
    if (_frames.isEmpty) {
      setState(() {
        _errorMessage =
            'No changed frames were captured yet. Scroll the conversation before analyzing.';
        _state = _ScanState.error;
      });
      return;
    }

    setState(() => _state = _ScanState.analyzing);
    try {
      final framesForAnalysis = _selectFramesForAnalysis(_frames);
      final result = await ref.read(
        chatAnalysisProvider(
          ChatAnalysisRequestDto(
            platform: _selectedPlatform,
            sessionId: _sessionId,
            frames: framesForAnalysis,
          ),
        ).future,
      );
      await LocalAppStateStore.instance.saveLatestChatReport(result);
      if (isRiskLevelEligibleForCommunity(result.riskLevel)) {
        await LocalAppStateStore.instance.saveCommunityFlagEligibility(
          CommunityFlagEligibility(
            sourceType: 'chat',
            sourceRiskLevel: result.riskLevel,
            sourceSessionId: _sessionId,
            platform: _selectedPlatform,
          ),
        );
      } else {
        await LocalAppStateStore.instance.clearCommunityFlagEligibility();
      }
      setState(() {
        _report = result;
        _state = _ScanState.report;
      });
    } catch (e) {
      setState(() {
        _errorMessage = formatApiError(
          e,
          fallbackMessage: 'Chat analysis failed. Check the backend logs.',
        );
        _state = _ScanState.error;
      });
    }
  }

  List<String> _selectFramesForAnalysis(List<String> frames) {
    if (frames.length <= _maxFramesForAnalysis) {
      return List<String>.unmodifiable(frames);
    }

    final selected = <String>[];
    final lastIndex = frames.length - 1;
    final step = lastIndex / (_maxFramesForAnalysis - 1);

    for (var i = 0; i < _maxFramesForAnalysis; i += 1) {
      final index = (i * step).round().clamp(0, lastIndex);
      selected.add(frames[index]);
    }

    return List<String>.unmodifiable(selected);
  }

  void _reset() => setState(() {
        _captureTimer?.cancel();
        _state = _ScanState.idle;
        _report = null;
        _errorMessage = null;
        _frames.clear();
        _frameCount = 0;
      });

  @override
  Widget build(BuildContext context) {
    ref.watch(backendReadinessProvider);
    return EditorialPage(
      centered: true,
      maxContentWidth: 540,
      child: switch (_state) {
        _ScanState.idle => _buildIdle(),
        _ScanState.scanning => _buildScanning(),
        _ScanState.analyzing => _buildAnalyzing(),
        _ScanState.report => _buildReport(_report!),
        _ScanState.error => _buildError(),
      },
    );
  }

  bool _canUseChatAnalysis() {
    final readiness = ref.read(backendReadinessProvider).valueOrNull;
    return readiness?.capabilityEnabled('chat_analysis') ?? true;
  }

  String _chatCapabilityMessage() {
    final readiness = ref.read(backendReadinessProvider).valueOrNull;
    if (readiness == null) {
      return 'Chat analysis is not ready yet. Retry after the backend status finishes loading.';
    }
    if (!readiness.isReachable) {
      return 'Start the backend first to analyze chat screenshots.';
    }
    return 'Chat analysis is unavailable until OPENROUTER_API_KEY is configured.';
  }

  IconData _platformIcon(String platform) {
    switch (platform) {
      case 'WhatsApp':
        return Icons.chat;
      case 'Telegram':
        return Icons.send_rounded;
      case 'Instagram':
        return Icons.camera_alt_outlined;
      case 'Dating App':
        return Icons.favorite_border;
      default:
        return Icons.forum_outlined;
    }
  }

  Widget _buildIdle() {
    final canUseChat = _canUseChatAnalysis();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EditorialEyebrow(
          label: 'ACTIVE INTELLIGENCE',
          icon: Icons.security,
        ),
        const SizedBox(height: 18),
        Text(
          'Chat\nMonitor',
          style: AppTheme.headline(
            42,
            weight: FontWeight.w800,
            color: AppTheme.primary,
            height: 0.94,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Open any conversation and scroll naturally while the monitor captures only changed frames in memory. Then generate a risk report from live evidence.',
          style: AppTheme.body(
            14,
            color: AppTheme.onSurfaceVariant,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          decoration: AppTheme.gradientBox(radius: 32),
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.forum, size: 38, color: Colors.white),
              ),
              const SizedBox(height: 18),
              Text(
                'Live Risk Detection',
                style: AppTheme.headline(
                  24,
                  color: Colors.white,
                  weight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Scroll through a suspicious conversation. The model looks for money requests, urgency, manipulation, and identity inconsistencies.',
                textAlign: TextAlign.center,
                style: AppTheme.body(
                  13,
                  color: Colors.white.withValues(alpha: 0.84),
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose platform',
                  style: AppTheme.label(
                    10,
                    color: Colors.white.withValues(alpha: 0.78),
                    weight: FontWeight.w700,
                    letterSpacing: 1.8,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: _platforms
                    .map(
                      (platform) => _PlatformChoiceChip(
                        label: platform,
                        icon: _platformIcon(platform),
                        selected: _selectedPlatform == platform,
                        onTap: () => setState(() => _selectedPlatform = platform),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              GradientCtaButton(
                label: 'Start Scan',
                icon: Icons.arrow_forward,
                onPressed: _startScan,
                enabled: canUseChat,
              ),
              if (!canUseChat) ...[
                const SizedBox(height: 12),
                Text(
                  _chatCapabilityMessage(),
                  textAlign: TextAlign.center,
                  style: AppTheme.body(
                    11,
                    color: Colors.white.withValues(alpha: 0.84),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        const EditorialSectionTitle(
          title: 'How it works',
          subtitle: 'A privacy-first monitor that behaves like a premium safety overlay.',
        ),
        const SizedBox(height: 14),
        const _MonitorCapabilityTile(
          icon: Icons.visibility_outlined,
          title: 'Passive frame capture',
          body:
              'The scanner captures two frames per second and discards duplicates before analysis.',
        ),
        const SizedBox(height: 12),
        const _MonitorCapabilityTile(
          icon: Icons.psychology_alt_outlined,
          title: 'Behavioral deception signals',
          body:
              'The model watches for emotional leverage, financial urgency, and verification avoidance.',
        ),
        const SizedBox(height: 28),
        const EditorialSectionTitle(
          title: 'Recent Activity',
          subtitle: 'Mock feed for the first rewrite pass.',
          trailing: MockTag(),
        ),
        const SizedBox(height: 14),
        const _RecentActivityCard(
          title: 'WhatsApp Thread #242',
          meta: 'Live scan · 14:20',
          label: 'Low Risk',
          score: 12,
        ),
        const SizedBox(height: 12),
        const _RecentActivityCard(
          title: 'Messenger Activity',
          meta: 'Potential threat · 09:15',
          label: 'Potential Threat',
          score: 45,
        ),
        const SizedBox(height: 12),
        const _RecentActivityCard(
          title: 'Dating App Scan',
          meta: 'Clean conversation · 22:04',
          label: 'Clean',
          score: 5,
        ),
      ],
    );
  }

  Widget _buildScanning() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EditorialEyebrow(
          label: 'ACTIVE MONITORING',
          icon: Icons.radar,
        ),
        const SizedBox(height: 18),
        Text(
          'Scroll naturally.\nWe are watching for signal.',
          style: AppTheme.headline(
            34,
            weight: FontWeight.w800,
            color: AppTheme.primary,
            height: 0.98,
          ),
        ),
        const SizedBox(height: 18),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppTheme.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Recording in progress',
                    style: AppTheme.headline(
                      16,
                      color: AppTheme.error,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$_frameCount frames',
                    style: AppTheme.label(10),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const SplitBackgroundFill(height: 190),
              const SizedBox(height: 18),
              TonalPanel(
                radius: 22,
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Only changed frames are kept in memory. Nothing from the conversation is written to disk.',
                        style: AppTheme.body(
                          12,
                          color: AppTheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              GradientCtaButton(
                label: 'Analyze Captured Frames',
                icon: Icons.auto_awesome,
                onPressed: _analyze,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyzing() {
    return Center(
      child: GlassPanel(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EditorialEyebrow(
              label: 'ANALYZING',
              icon: Icons.psychology_alt_outlined,
            ),
            const SizedBox(height: 16),
            Text(
              'Composing the report',
              style: AppTheme.headline(
                28,
                color: AppTheme.primary,
                weight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'The model is reviewing the captured sequence for coercion patterns, urgency language, and trust inconsistencies.',
              textAlign: TextAlign.center,
              style: AppTheme.body(
                13,
                color: AppTheme.onSurfaceVariant,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 20),
            const LinearProgressIndicator(
              color: AppTheme.primaryContainer,
              minHeight: 6,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReport(RiskReport report) {
    final color = AppTheme.riskLevelColor(report.riskLevel);
    final canFlagProfile = isRiskLevelEligibleForCommunity(report.riskLevel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EditorialEyebrow(
          label: 'REPORT STATE',
          icon: Icons.insights_outlined,
        ),
        const SizedBox(height: 18),
        Stack(
          children: [
            const Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(top: 36, bottom: 36),
                child: SplitBackgroundFill(height: 460),
              ),
            ),
            GlassPanel(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RiskBadge(label: report.riskLevel),
                            const SizedBox(height: 14),
                            Text(
                              'Sentiment\nAnalysis',
                              style: AppTheme.headline(
                                30,
                                color: AppTheme.onSurface,
                                weight: FontWeight.w800,
                                height: 0.95,
                              ),
                            ),
                          ],
                        ),
                      ),
                      MetricRing(
                        score: report.riskScore,
                        label: 'RISK SCORE',
                        color: color,
                        size: 108,
                      ),
                    ],
                  ),
                  if (report.redFlags.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'DETECTED INDICATORS',
                      style: AppTheme.label(11, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    ...report.redFlags.map(
                      (flag) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _IndicatorCard(flag: flag),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TonalPanel(
                    color: AppTheme.surfaceLow,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PROFESSIONAL INSIGHT',
                          style: AppTheme.label(11, weight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          report.summary,
                          style: AppTheme.body(
                            13,
                            weight: FontWeight.w600,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (report.recommendedActions.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'SAFEGUARD PROTOCOL',
                      style: AppTheme.label(11, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    ...report.recommendedActions.map(
                      (action) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SafeguardRow(action: action),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  GradientCtaButton(
                    label: 'Flag This Profile',
                    icon: Icons.flag_outlined,
                    onPressed: canFlagProfile ? _openCommunityFlagFlow : null,
                    enabled: canFlagProfile,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _reset,
                      child: const Text('Close Report'),
                    ),
                  ),
                  if (!canFlagProfile) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Community flagging unlocks after a completed scan result.',
                      textAlign: TextAlign.center,
                      style: AppTheme.body(
                        11,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: GlassPanel(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.errorContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.error_outline,
                color: AppTheme.error,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Analysis failed',
              style: AppTheme.headline(
                24,
                color: AppTheme.error,
                weight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style: AppTheme.body(
                13,
                color: AppTheme.onSurfaceVariant,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: _reset,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCommunityFlagFlow() async {
    final eligibility =
        await LocalAppStateStore.instance.loadCommunityFlagEligibility();
    final lastLookup =
        await LocalAppStateStore.instance.loadLastCommunityLookup();
    if (!mounted || eligibility == null) {
      return;
    }

    ref.read(communityLaunchIntentProvider.notifier).state =
        CommunityLaunchIntent(
      launchId: DateTime.now().microsecondsSinceEpoch,
      mode: CommunityLaunchMode.flag,
      platform: eligibility.platform ?? _selectedPlatform,
      handle: eligibility.handle ?? lastLookup?.handle,
      phone: eligibility.phone ?? lastLookup?.phone,
      photoHash: eligibility.photoHash,
    );
    ref.read(shellTabProvider.notifier).state = ShellTab.circle;
  }
}

class _MonitorCapabilityTile extends StatelessWidget {
  const _MonitorCapabilityTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return TonalPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryFixed,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppTheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.headline(15, weight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: AppTheme.body(
                    12,
                    color: AppTheme.onSurfaceVariant,
                    height: 1.55,
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

class _PlatformChoiceChip extends StatelessWidget {
  const _PlatformChoiceChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background =
        selected ? Colors.white : Colors.white.withValues(alpha: 0.12);
    final foreground =
        selected ? AppTheme.primary : Colors.white.withValues(alpha: 0.92);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.14),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTheme.body(
                12,
                color: foreground,
                weight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({
    required this.title,
    required this.meta,
    required this.label,
    required this.score,
  });

  final String title;
  final String meta;
  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.riskColor(100 - score);
    final safeLabel = label.toUpperCase();

    return SurfacePanel(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.verified_user_outlined, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.headline(15, weight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  meta,
                  style: AppTheme.body(12, color: AppTheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                safeLabel,
                style: AppTheme.label(
                  10,
                  color: color,
                  weight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 52,
                height: 6,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: (score / 100).clamp(0.04, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IndicatorCard extends StatelessWidget {
  const _IndicatorCard({required this.flag});

  final RedFlag flag;

  @override
  Widget build(BuildContext context) {
    final severityColor = AppTheme.severityColor(flag.severity);
    final severityBg = AppTheme.severityBackground(flag.severity);

    return SurfacePanel(
      padding: const EdgeInsets.all(18),
      radius: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: severityColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        flag.pattern,
                        style: AppTheme.headline(15, weight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 8),
                    RiskBadge(
                      label: flag.severity,
                      color: severityColor,
                      background: severityBg,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  flag.evidence,
                  style: AppTheme.body(
                    12,
                    color: AppTheme.onSurfaceVariant,
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

class _SafeguardRow extends StatelessWidget {
  const _SafeguardRow({required this.action});

  final String action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 5),
          decoration: const BoxDecoration(
            color: AppTheme.error,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            action,
            style: AppTheme.body(13, height: 1.5),
          ),
        ),
      ],
    );
  }
}
