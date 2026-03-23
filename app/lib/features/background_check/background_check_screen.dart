// Owner: Member 1
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/app_state.dart';
import '../../core/models/background_check_result.dart';
import '../../core/models/community_flag.dart';
import '../../core/models/requests.dart';
import '../../core/storage/local_app_state_store.dart';
import '../../core/theme/app_theme.dart';
import '../community/community_provider.dart';
import 'background_check_provider.dart';
import 'background_check_stream_provider.dart';
import 'background_check_utils.dart';

class BackgroundCheckScreen extends ConsumerStatefulWidget {
  const BackgroundCheckScreen({super.key});

  @override
  ConsumerState<BackgroundCheckScreen> createState() =>
      _BackgroundCheckScreenState();
}

class _BackgroundCheckScreenState
    extends ConsumerState<BackgroundCheckScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedPlatform = 'X';
  bool _showManualFields = false;

  // Manual path (FutureProvider)
  BackgroundCheckRequestDto? _params;
  // URL path (StreamProvider)
  BackgroundCheckStreamRequestDto? _streamParams;
  final List<BackgroundCheckEvent> _streamEvents = [];
  String? _lastEligibilitySessionId;

  static const _platforms = [
    'X',
    'GitHub',
    'Instagram',
    'Telegram',
    'WhatsApp',
    'Dating App',
    'Other'
  ];

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    if (!_formKey.currentState!.validate()) return;
    final url = _urlController.text.trim();
    final username = _usernameController.text.trim();
    final phone = _phoneController.text.trim();

    if (url.isNotEmpty) {
      // URL mode — stream SSE
      setState(() {
        _streamEvents.clear();
        _params = null;
        _streamParams = BackgroundCheckStreamRequestDto(
          profileUrl: url,
          username: username,
          platform: _selectedPlatform,
          phone: phone.isNotEmpty ? phone : null,
        );
      });
    } else {
      // Manual mode — FutureProvider
      setState(() {
        _streamParams = null;
        _params = BackgroundCheckRequestDto(
          username: username,
          platform: _selectedPlatform,
          phone: phone.isNotEmpty ? phone : null,
        );
      });
    }
  }

  void _reset() {
    setState(() {
      _params = null;
      _streamParams = null;
      _streamEvents.clear();
      _lastEligibilitySessionId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ── URL/SSE streaming path ─────────────────────────────────────────────
    if (_streamParams != null) {
      final stream = ref.watch(backgroundCheckStreamProvider(_streamParams!));
      stream.whenData((event) {
        if (!_streamEvents.any(
            (e) => e.step == event.step && e.message == event.message)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _streamEvents.add(event));
          });
        }
      });

      final latestResult = _streamEvents
          .where((e) => e.step == CheckStep.complete && e.result != null)
          .map((e) => e.result!)
          .lastOrNull;

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStreamProgress(),
            if (latestResult != null) ...[
              const SizedBox(height: 12),
              _buildResult(latestResult),
            ],
          ],
        ),
      );
    }

    // ── Manual FutureProvider path ─────────────────────────────────────────
    final result =
        _params != null ? ref.watch(backgroundCheckProvider(_params!)) : null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: result == null
          ? _buildForm()
          : result.when(
              data: _buildResult,
              loading: _buildLoading,
              error: _buildError,
            ),
    );
  }

  // ── Form ──────────────────────────────────────────────────────────────────

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.manage_search,
                  size: 18, color: AppTheme.primaryContainer),
              const SizedBox(width: 8),
              Text('OSINT Search', style: AppTheme.headline(15)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Paste a profile URL for automated analysis, or enter details manually.',
            style: AppTheme.body(11, color: AppTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          // ── Primary: Profile URL ─────────────────────────────────────────
          TextFormField(
            controller: _urlController,
            style: AppTheme.body(13),
            decoration: const InputDecoration(
              labelText: 'Profile URL',
              hintText: 'e.g. https://instagram.com/john_doe',
              prefixIcon: Icon(Icons.link, size: 18),
            ),
          ),
          const SizedBox(height: 10),
          // ── Collapsible manual fields ────────────────────────────────────
          GestureDetector(
            onTap: () =>
                setState(() => _showManualFields = !_showManualFields),
            child: Row(children: [
              Icon(
                _showManualFields
                    ? Icons.expand_less
                    : Icons.expand_more,
                size: 14,
                color: AppTheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                'Manual fields (optional)',
                style: AppTheme.label(11),
              ),
            ]),
          ),
          if (_showManualFields) ...[
            const SizedBox(height: 10),
            TextFormField(
              controller: _usernameController,
              style: AppTheme.body(13),
              decoration: const InputDecoration(
                labelText: 'Username / Handle',
                hintText: 'e.g. john_doe123',
                prefixIcon: Icon(Icons.person_outline, size: 18),
              ),
              validator: (v) {
                // Username required only when no URL provided
                final url = _urlController.text.trim();
                if (url.isEmpty && (v == null || v.trim().isEmpty)) {
                  return 'Enter a URL or username';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedPlatform,
              style: AppTheme.body(13),
              decoration: const InputDecoration(
                labelText: 'Platform',
                prefixIcon: Icon(Icons.devices_outlined, size: 18),
              ),
              items: _platforms
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedPlatform = v!),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phoneController,
              style: AppTheme.body(13),
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                hintText: 'e.g. +60123456789',
                prefixIcon: Icon(Icons.phone_outlined, size: 18),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
          const SizedBox(height: 20),
          _GradientButton(
            label: 'Run Background Check',
            icon: Icons.search,
            onPressed: _onSubmit,
          ),
        ],
      ),
    );
  }

  // ── Streaming progress panel ───────────────────────────────────────────────

  Widget _buildStreamProgress() {
    final isComplete = _streamEvents.any((e) => e.step == CheckStep.complete);
    final hasError = _streamEvents.any((e) => e.step == CheckStep.error);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.tonalSection(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.radar, size: 13, color: AppTheme.primaryContainer),
            const SizedBox(width: 6),
            Text('Live Analysis', style: AppTheme.headline(11)),
            const Spacer(),
            if (isComplete || hasError)
              GestureDetector(
                onTap: _reset,
                child: Text('New Search',
                    style: AppTheme.label(10,
                        color: AppTheme.primaryContainer)),
              ),
          ]),
          const SizedBox(height: 8),
          if (_streamEvents.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: LinearProgressIndicator(
                  color: AppTheme.primaryContainer),
            )
          else ...[
            ..._streamEvents.map((e) => _StreamEventRow(event: e)),
            if (!isComplete && !hasError)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: LinearProgressIndicator(
                    color: AppTheme.primaryContainer),
              ),
          ],
        ],
      ),
    );
  }

  // ── Loading ───────────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 48),
        CircularProgressIndicator(
          color: AppTheme.primaryContainer,
          strokeWidth: 2.5,
        ),
        SizedBox(height: 14),
        Text('Running intelligence checks...',
            style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
      ],
    );
  }

  // ── Error ─────────────────────────────────────────────────────────────────

  Widget _buildError(Object error, StackTrace? _) {
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
          child: Column(
            children: [
              const Icon(Icons.error_outline,
                  color: AppTheme.error, size: 32),
              const SizedBox(height: 8),
              Text('Check failed',
                  style: AppTheme.headline(13, color: AppTheme.error)),
              const SizedBox(height: 4),
              Text(
                error.toString(),
                style: AppTheme.body(11, color: AppTheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _reset,
          child: const Text('Try Again'),
        ),
      ],
    );
  }

  // ── Results ───────────────────────────────────────────────────────────────

  Widget _buildResult(BackgroundCheckResult data) {
    final phones = data.discoveredIdentifiers?.phones ?? const <String>[];
    _persistCommunityEligibility(data);

    final lookup = CommunityProfileLookupDto(
      handle: data.scrapedProfile?.username,
      phone: _params?.phone ?? (phones.isNotEmpty ? phones.first : null),
      photoHash: data.photoHash,
    );
    final communityAsync =
        lookup.hasIdentifier ? ref.watch(profileCheckProvider(lookup)) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RiskDialCard(score: data.profileConsistencyScore),
        const SizedBox(height: 10),
        _ResultSection(
          title: 'Photo Verification',
          icon: Icons.image_search,
          child: data.photoFoundOnline
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusChip(
                        label: 'Found online',
                        color: AppTheme.error,
                        bg: AppTheme.errorContainer),
                    const SizedBox(height: 6),
                    ...data.photoSources.map(
                      (url) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.open_in_new,
                                size: 11,
                                color: AppTheme.primaryContainer),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(url,
                                  style: AppTheme.body(10,
                                      color: AppTheme.primaryContainer),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : const _GreenCheck('No online matches found'),
        ),
        if (_params?.phone != null) ...[
          const SizedBox(height: 8),
          _ResultSection(
            title: 'Phone Validation',
            icon: Icons.phone_outlined,
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _StatusChip(
                  label: data.phoneValid ? 'Valid' : 'Invalid',
                  color: data.phoneValid
                      ? const Color(0xFF2E7D32)
                      : AppTheme.error,
                  bg: data.phoneValid
                      ? const Color(0xFFE8F5E9)
                      : AppTheme.errorContainer,
                ),
                if (data.phoneCountry.isNotEmpty)
                  _InfoChip(label: data.phoneCountry),
                if (data.phoneCarrier != null)
                  _InfoChip(label: 'via ${data.phoneCarrier}'),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        _ResultSection(
          title: 'Platform Presence',
          icon: Icons.devices_outlined,
          child: data.usernamePlatforms.isEmpty
              ? Text('Not found on any checked platform',
                  style:
                      AppTheme.body(11, color: AppTheme.onSurfaceVariant))
              : Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: data.usernamePlatforms
                      .map((p) => _InfoChip(label: p))
                      .toList(),
                ),
        ),
        const SizedBox(height: 8),
        _ResultSection(
          title: 'Account Authenticity',
          icon: Icons.verified_user_outlined,
          child: _AuthenticitySection(data: data),
        ),
        if (data.findings.isNotEmpty) ...[
          const SizedBox(height: 8),
          _ResultSection(
            title: 'Risk Findings',
            icon: Icons.flag_outlined,
            child: _FindingsSection(findings: data.findings),
          ),
        ],
        if (communityAsync != null) ...[
          const SizedBox(height: 8),
          _ResultSection(
            title: 'Community Reports',
            icon: Icons.people_outline,
            child: communityAsync.when(
              data: (r) => _CommunityReportSection(result: r),
              loading: () => const SizedBox(
                height: 20,
                child: Center(
                    child: LinearProgressIndicator(
                        color: AppTheme.primaryContainer)),
              ),
              error: (_, __) => Text('Community check unavailable.',
                  style:
                      AppTheme.body(11, color: AppTheme.onSurfaceVariant)),
            ),
          ),
        ],
        const SizedBox(height: 8),
        _ResultSection(
          title: 'Summary',
          icon: Icons.summarize_outlined,
          child: Text(
            data.backgroundSummary,
            style: AppTheme.body(11,
                color: AppTheme.onSurfaceVariant,
                weight: FontWeight.normal),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _reset,
          child: const Text('New Search'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  void _persistCommunityEligibility(BackgroundCheckResult data) {
    final riskLevel = data.riskLevel ?? _riskLevelFromConsistencyScore(
      data.profileConsistencyScore,
    );
    final sessionId = _streamParams?.profileUrl ?? _params?.username ?? 'background-check';
    if (_lastEligibilitySessionId == sessionId) {
      return;
    }

    _lastEligibilitySessionId = sessionId;
    if (!isRiskLevelEligibleForCommunity(riskLevel)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        LocalAppStateStore.instance.clearCommunityFlagEligibility();
      });
      return;
    }

    final handles = data.discoveredIdentifiers?.handles ?? const [];
    final phones = data.discoveredIdentifiers?.phones ?? const <String>[];
    final handle = data.scrapedProfile?.username ??
        (handles.isNotEmpty ? handles.first : null);
    final phone = _params?.phone ?? (phones.isNotEmpty ? phones.first : null);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      LocalAppStateStore.instance.saveCommunityFlagEligibility(
        CommunityFlagEligibility(
          sourceType: 'background_check',
          sourceRiskLevel: riskLevel,
          sourceSessionId: sessionId,
          handle: handle,
          phone: phone,
          photoHash: data.photoHash,
        ),
      );
    });
  }
}

String _riskLevelFromConsistencyScore(int score) {
  if (score < 20) {
    return 'CRITICAL';
  }
  if (score < 40) {
    return 'HIGH';
  }
  if (score < 70) {
    return 'MEDIUM';
  }
  return 'LOW';
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

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

class _RiskDialCard extends StatelessWidget {
  final int score;
  const _RiskDialCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.riskColor(score);
    final bg = AppTheme.riskBackground(score);
    final label = AppTheme.riskLabel(score);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.surfaceCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score',
                style: GoogleFonts.manrope(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 2),
                child: Text('/100',
                    style: AppTheme.body(12,
                        color: AppTheme.onSurfaceVariant)),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(label,
                    style: AppTheme.label(10, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: AppTheme.surfaceContainer,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 6),
          Text('CONSISTENCY SCORE',
              style: AppTheme.label(9,
                  color: AppTheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _ResultSection(
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

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  const _StatusChip(
      {required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: AppTheme.label(10, color: color)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: AppTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: AppTheme.label(10)),
    );
  }
}

class _GreenCheck extends StatelessWidget {
  final String label;
  const _GreenCheck(this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_outline,
            size: 13, color: Color(0xFF2E7D32)),
        const SizedBox(width: 4),
        Text(label,
            style: AppTheme.body(11, color: const Color(0xFF2E7D32))),
      ],
    );
  }
}

// ── Authenticity Section ──────────────────────────────────────────────────────

class _AuthenticitySection extends StatelessWidget {
  final BackgroundCheckResult data;
  const _AuthenticitySection({required this.data});

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final note = data.authenticityNote;
    final Color bannerColor;
    final Color textColor;
    if (note.startsWith('High confidence')) {
      bannerColor = const Color(0xFFE8F5E9);
      textColor = const Color(0xFF2E7D32);
    } else if (note.startsWith('Warning')) {
      bannerColor = AppTheme.errorContainer;
      textColor = AppTheme.error;
    } else {
      bannerColor = const Color(0xFFFFF8E1);
      textColor = const Color(0xFFF57F17);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _StatusChip(
              label: data.platformVerified ? 'Verified' : 'Not Verified',
              color: data.platformVerified
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFF57F17),
              bg: data.platformVerified
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFF8E1),
            ),
            if (data.platformFollowers != null)
              _InfoChip(label: '${_fmt(data.platformFollowers!)} followers'),
            if (data.platformAccountAgeDays != null)
              _StatusChip(
                label: '${data.platformAccountAgeDays!}d old',
                color: data.platformAccountAgeDays! < 90
                    ? AppTheme.error
                    : AppTheme.primaryContainer,
                bg: data.platformAccountAgeDays! < 90
                    ? AppTheme.errorContainer
                    : const Color(0xFFE3F2FD),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: bannerColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child:
              Text(note, style: AppTheme.body(11, color: textColor)),
        ),
      ],
    );
  }
}

// ── Stream Event Row ──────────────────────────────────────────────────────────

class _StreamEventRow extends StatelessWidget {
  final BackgroundCheckEvent event;
  const _StreamEventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final IconData iconData;
    final Color iconColor;
    if (event.step == CheckStep.complete) {
      iconData = Icons.check_circle;
      iconColor = const Color(0xFF2E7D32);
    } else if (event.step == CheckStep.error) {
      iconData = Icons.error_outline;
      iconColor = AppTheme.error;
    } else if (event.isFlag) {
      final sev = event.severity ?? '';
      iconColor = sev == 'critical' || sev == 'high'
          ? AppTheme.error
          : const Color(0xFFF57F17);
      iconData = Icons.warning_amber_rounded;
    } else if (event.status == 'started') {
      iconData = Icons.hourglass_empty;
      iconColor = AppTheme.onSurfaceVariant;
    } else {
      iconData = Icons.check_circle_outline;
      iconColor = AppTheme.primaryContainer;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(iconData, size: 12, color: iconColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(event.message,
                style: AppTheme.body(11,
                    color: event.isFlag
                        ? AppTheme.onSurface
                        : AppTheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

// ── Findings Section ──────────────────────────────────────────────────────────

class _FindingsSection extends StatelessWidget {
  final List<DossierFinding> findings;
  const _FindingsSection({required this.findings});

  static int _rank(String s) =>
      const {'critical': 0, 'high': 1, 'medium': 2, 'low': 3}[s] ?? 4;

  @override
  Widget build(BuildContext context) {
    final sorted = [...findings]
      ..sort((a, b) => _rank(a.severity).compareTo(_rank(b.severity)));
    return Column(
      children: sorted.map((f) => _FindingRow(finding: f)).toList(),
    );
  }
}

class _FindingRow extends StatelessWidget {
  final DossierFinding finding;
  const _FindingRow({required this.finding});

  @override
  Widget build(BuildContext context) {
    final Color chipColor;
    final Color chipBg;
    switch (finding.severity) {
      case 'critical':
      case 'high':
        chipColor = AppTheme.error;
        chipBg = AppTheme.errorContainer;
      case 'medium':
        chipColor = const Color(0xFFF57F17);
        chipBg = const Color(0xFFFFF3E0);
      default:
        chipColor = AppTheme.primaryContainer;
        chipBg = const Color(0xFFE3F2FD);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusChip(
              label: finding.severity.toUpperCase(),
              color: chipColor,
              bg: chipBg),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(finding.flag,
                    style: AppTheme.body(11,
                        weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(finding.evidence,
                    style: AppTheme.body(10,
                        color: AppTheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Community Report Section ──────────────────────────────────────────────────

class _CommunityReportSection extends StatelessWidget {
  final ProfileCheckResult result;
  const _CommunityReportSection({required this.result});

  @override
  Widget build(BuildContext context) {
    if (!result.flagged) {
      return const _GreenCheck('No community reports for this photo');
    }
    final statusColor = result.status == 'confirmed'
        ? AppTheme.error
        : result.status == 'flagged'
            ? const Color(0xFFF57F17)
            : const Color(0xFFF9A825);
    final statusBg = result.status == 'confirmed'
        ? AppTheme.errorContainer
        : result.status == 'flagged'
            ? const Color(0xFFFFF3E0)
            : const Color(0xFFFFFDE7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _StatusChip(
              label:
                  '${result.reportCount ?? 0} report${(result.reportCount ?? 0) == 1 ? "" : "s"}',
              color: statusColor,
              bg: statusBg,
            ),
            if (result.status != null)
              _StatusChip(
                  label: result.status!.toUpperCase(),
                  color: statusColor,
                  bg: statusBg),
            if (result.region != null) _InfoChip(label: result.region!),
          ],
        ),
        if (result.firstReported != null) ...[
          const SizedBox(height: 4),
          Text('First reported: ${result.firstReported}',
              style: AppTheme.label(10)),
        ],
        if (result.commonFlags != null &&
            result.commonFlags!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: result.commonFlags!
                .map((f) => _StatusChip(
                    label: f,
                    color: AppTheme.error,
                    bg: AppTheme.errorContainer))
                .toList(),
          ),
        ],
      ],
    );
  }
}
