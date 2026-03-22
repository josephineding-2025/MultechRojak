// Owner: Member 2
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/risk_report.dart';
import '../../core/theme/app_theme.dart';
import 'chat_monitor_provider.dart';

enum _ScanState { idle, scanning, analyzing, report, error }

class ChatMonitorScreen extends ConsumerStatefulWidget {
  const ChatMonitorScreen({super.key});

  @override
  ConsumerState<ChatMonitorScreen> createState() => _ChatMonitorScreenState();
}

class _ChatMonitorScreenState extends ConsumerState<ChatMonitorScreen> {
  _ScanState _state = _ScanState.idle;
  int _frameCount = 0;
  RiskReport? _report;
  String? _errorMessage;

  // Simulated session id — real implementation collects frames via screen_capturer
  final String _sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
  final List<String> _frames = [];

  void _startScan() => setState(() {
        _state = _ScanState.scanning;
        _frameCount = 0;
        _frames.clear();
      });

  Future<void> _analyze() async {
    setState(() => _state = _ScanState.analyzing);
    try {
      final result = await ref.read(
        chatAnalysisProvider({
          'platform': 'Unknown',
          'session_id': _sessionId,
        }).future,
      );
      setState(() {
        _report = result;
        _state = _ScanState.report;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _state = _ScanState.error;
      });
    }
  }

  void _reset() => setState(() {
        _state = _ScanState.idle;
        _report = null;
        _errorMessage = null;
        _frames.clear();
      });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: switch (_state) {
        _ScanState.idle => _buildIdle(),
        _ScanState.scanning => _buildScanning(),
        _ScanState.analyzing => _buildAnalyzing(),
        _ScanState.report => _buildReport(_report!),
        _ScanState.error => _buildError(),
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
          const Icon(Icons.forum_outlined,
              size: 18, color: AppTheme.primaryContainer),
          const SizedBox(width: 8),
          Text('Chat Monitor', style: AppTheme.headline(15)),
        ]),
        const SizedBox(height: 4),
        Text(
          'Scroll through a conversation while scanning. Our AI flags romance scam patterns in real time.',
          style: AppTheme.body(11, color: AppTheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        _GradientButton(
          label: 'Start Scan',
          icon: Icons.radar,
          onPressed: _startScan,
        ),
        const SizedBox(height: 20),
        Text('HOW IT WORKS',
            style: AppTheme.label(9, color: AppTheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        _HowItWorksCard(
          icon: Icons.visibility_outlined,
          title: 'Passive capture',
          body:
              'Captures 2 frames/second while you scroll. Nothing is stored on disk.',
        ),
        const SizedBox(height: 8),
        _HowItWorksCard(
          icon: Icons.psychology_outlined,
          title: 'AI risk analysis',
          body:
              'Vision LLM scans for money requests, urgency language, identity inconsistencies.',
        ),
      ],
    );
  }

  // ── Scanning ─────────────────────────────────────────────────────────────

  Widget _buildScanning() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.surfaceCard(),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.error,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text('Recording',
                  style: AppTheme.headline(13, color: AppTheme.error)),
              const Spacer(),
              Text('$_frameCount frames',
                  style: AppTheme.label(10)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Scroll through the conversation now. Press Analyze when done.',
          style: AppTheme.body(11, color: AppTheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        _GradientButton(
          label: 'Analyze',
          icon: Icons.auto_fix_high,
          onPressed: _analyze,
        ),
      ],
    );
  }

  // ── Analyzing ────────────────────────────────────────────────────────────

  Widget _buildAnalyzing() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 48),
        const LinearProgressIndicator(color: AppTheme.primaryContainer),
        const SizedBox(height: 16),
        Text('Analyzing frames...',
            style: AppTheme.body(12, color: AppTheme.onSurfaceVariant)),
      ],
    );
  }

  // ── Report ───────────────────────────────────────────────────────────────

  Widget _buildReport(RiskReport report) {
    final color = _riskColor(report.riskLevel);
    final bg = _riskBg(report.riskLevel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.surfaceCard(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${report.riskScore}',
                style: GoogleFonts.manrope(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 2),
                child: Text('/100',
                    style:
                        AppTheme.body(12, color: AppTheme.onSurfaceVariant)),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: bg, borderRadius: BorderRadius.circular(20)),
                child: Text(report.riskLevel,
                    style: AppTheme.label(10, color: color)),
              ),
            ],
          ),
        ),
        if (report.redFlags.isNotEmpty) ...[
          const SizedBox(height: 10),
          _SectionBox(
            title: 'Red Flags',
            icon: Icons.warning_amber_outlined,
            child: Column(
              children: report.redFlags
                  .map((f) => _RedFlagCard(flag: f))
                  .toList(),
            ),
          ),
        ],
        if (report.recommendedActions.isNotEmpty) ...[
          const SizedBox(height: 8),
          _SectionBox(
            title: 'Recommended Actions',
            icon: Icons.checklist_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: report.recommendedActions
                  .map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.arrow_right,
                                size: 14,
                                color: AppTheme.primaryContainer),
                            const SizedBox(width: 4),
                            Expanded(
                                child: Text(a, style: AppTheme.body(11))),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
        if (report.summary.isNotEmpty) ...[
          const SizedBox(height: 8),
          _SectionBox(
            title: 'Summary',
            icon: Icons.summarize_outlined,
            child: Text(report.summary,
                style: AppTheme.body(11,
                    color: AppTheme.onSurfaceVariant)),
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _reset,
          child: const Text('New Scan'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Error ─────────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            const Icon(Icons.error_outline, color: AppTheme.error, size: 28),
            const SizedBox(height: 6),
            Text('Analysis failed',
                style: AppTheme.headline(13, color: AppTheme.error)),
            const SizedBox(height: 4),
            Text(_errorMessage ?? '',
                style: AppTheme.body(11, color: AppTheme.onSurfaceVariant),
                textAlign: TextAlign.center),
          ]),
        ),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: _reset, child: const Text('Try Again')),
      ],
    );
  }
}

// ── Risk helpers ──────────────────────────────────────────────────────────────

Color _riskColor(String level) {
  switch (level.toUpperCase()) {
    case 'HIGH':
    case 'CRITICAL':
      return AppTheme.error;
    case 'MEDIUM':
      return const Color(0xFFF57F17);
    default:
      return const Color(0xFF2E7D32);
  }
}

Color _riskBg(String level) {
  switch (level.toUpperCase()) {
    case 'HIGH':
    case 'CRITICAL':
      return AppTheme.errorContainer;
    case 'MEDIUM':
      return const Color(0xFFFFF8E1);
    default:
      return const Color(0xFFE8F5E9);
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

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

class _HowItWorksCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _HowItWorksCard(
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

class _SectionBox extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionBox(
      {required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.tonalSection(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 13, color: AppTheme.primaryContainer),
            const SizedBox(width: 6),
            Text(title, style: AppTheme.headline(11)),
          ]),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _RedFlagCard extends StatelessWidget {
  final RedFlag flag;
  const _RedFlagCard({required this.flag});

  @override
  Widget build(BuildContext context) {
    final severityColor = flag.severity == 'critical' || flag.severity == 'high'
        ? AppTheme.error
        : const Color(0xFFF57F17);
    final severityBg = flag.severity == 'critical' || flag.severity == 'high'
        ? AppTheme.errorContainer
        : const Color(0xFFFFF8E1);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLowest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: Text(flag.pattern, style: AppTheme.headline(11))),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: severityBg,
                  borderRadius: BorderRadius.circular(10)),
              child: Text(flag.severity.toUpperCase(),
                  style: AppTheme.label(9, color: severityColor)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(flag.evidence,
              style: AppTheme.body(10, color: AppTheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
