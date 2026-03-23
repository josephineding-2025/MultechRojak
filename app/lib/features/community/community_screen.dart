// Owner: Member 3
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/app_state.dart';
import '../../core/models/community_flag.dart';
import '../../core/models/requests.dart';
import '../../core/storage/local_app_state_store.dart';
import '../../core/theme/app_theme.dart';
import 'community_provider.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  // ── Check Profile ──────────────────────────────────────────────────────────
  final _checkController = TextEditingController();
  CommunityProfileLookupDto? _checkParams;

  // ── Flag Scammer ──────────────────────────────────────────────────────────
  final _flagHandleController = TextEditingController();
  final _flagPhoneController = TextEditingController();
  String _flagPlatform = 'Telegram';
  String _flagRegion = 'MY';
  final Set<String> _selectedFlags = {};
  CommunityFlagRequestDto? _flagParams;
  AppSettings _settings = const AppSettings();
  CommunityFlagEligibility? _eligibility;
  bool _loadingState = true;

  static const _platforms = [
    'Telegram', 'WhatsApp', 'Instagram', 'X', 'Dating App', 'Other'
  ];
  static const _regions = ['MY', 'SG', 'PH', 'ID', 'TH', 'VN', 'Other'];
  static const _flagOptions = [
    'money request',
    'fake investment',
    'identity inconsistency',
    'catfishing',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    _loadLocalState();
  }

  @override
  void dispose() {
    _checkController.dispose();
    _flagHandleController.dispose();
    _flagPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalState() async {
    final settings = await LocalAppStateStore.instance.loadSettings();
    final eligibility =
        await LocalAppStateStore.instance.loadCommunityFlagEligibility();
    if (!mounted) {
      return;
    }

    if ((_flagHandleController.text.isEmpty) && eligibility?.handle != null) {
      _flagHandleController.text = eligibility!.handle!;
    }
    if ((_flagPhoneController.text.isEmpty) && eligibility?.phone != null) {
      _flagPhoneController.text = eligibility!.phone!;
    }

    setState(() {
      _settings = settings;
      _eligibility = eligibility;
      _loadingState = false;
    });
  }

  Future<void> _toggleContribution(bool value) async {
    final nextSettings = AppSettings(communityContributionEnabled: value);
    await LocalAppStateStore.instance.saveSettings(nextSettings);
    if (!mounted) {
      return;
    }
    setState(() => _settings = nextSettings);
  }

  void _runCheck() {
    final q = _checkController.text.trim();
    if (q.isEmpty) return;
    setState(
      () => _checkParams = CommunityProfileLookupDto(
        phone: q.startsWith('+') || RegExp(r'^\d').hasMatch(q) ? q : null,
        handle: q.startsWith('+') || RegExp(r'^\d').hasMatch(q) ? null : q,
      ),
    );
  }

  void _submitFlag() {
    if (!_settings.communityContributionEnabled || _eligibility == null) {
      return;
    }

    final handle = _flagHandleController.text.trim();
    final phone = _flagPhoneController.text.trim();
    final effectiveHandle = handle.isNotEmpty ? handle : _eligibility!.handle;
    final effectivePhone = phone.isNotEmpty ? phone : _eligibility!.phone;
    final photoHash = _eligibility!.photoHash;

    if ((effectiveHandle == null || effectiveHandle.isEmpty) &&
        (effectivePhone == null || effectivePhone.isEmpty) &&
        (photoHash == null || photoHash.isEmpty)) {
      return;
    }
    if (_selectedFlags.isEmpty) {
      return;
    }

    setState(
      () => _flagParams = CommunityFlagRequestDto(
        platform: _flagPlatform,
        handle: effectiveHandle,
        phone: effectivePhone,
        photoHash: photoHash,
        flags: _selectedFlags.toList(),
        region: _flagRegion,
        sourceType: _eligibility!.sourceType,
        sourceRiskLevel: _eligibility!.sourceRiskLevel,
        sourceSessionId: _eligibility!.sourceSessionId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.group_outlined,
                size: 18, color: AppTheme.primaryContainer),
            const SizedBox(width: 8),
            Text('Community Circle', style: AppTheme.headline(15)),
          ]),
          const SizedBox(height: 4),
          Text(
            'Check if a profile has been reported, or flag a confirmed scammer.',
            style: AppTheme.body(11, color: AppTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: AppTheme.tonalSection(),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Community contribution', style: AppTheme.headline(11)),
                      const SizedBox(height: 2),
                      Text(
                        'Turn this off to keep your future scan results local only.',
                        style: AppTheme.body(
                          10,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _settings.communityContributionEnabled,
                  onChanged: _toggleContribution,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Check Profile ────────────────────────────────────────────────
          Text('CHECK PROFILE',
              style: AppTheme.label(9, color: AppTheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _checkController,
                  style: AppTheme.body(13),
                  decoration: const InputDecoration(
                    hintText: 'Handle or phone number',
                    prefixIcon:
                        Icon(Icons.search_outlined, size: 18),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _runCheck,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: AppTheme.gradientBox(radius: 12),
                  child: Center(
                    child: Text('Check',
                        style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_checkParams != null) _CheckResult(params: _checkParams!),

          const SizedBox(height: 24),

          // ── Divider ──────────────────────────────────────────────────────
          Container(height: 1, color: AppTheme.surfaceContainer),
          const SizedBox(height: 20),

          // ── Flag Scammer ─────────────────────────────────────────────────
          Text('FLAG SCAMMER',
              style: AppTheme.label(9, color: AppTheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          if (_loadingState)
            const LinearProgressIndicator(color: AppTheme.primaryContainer)
          else if (!_settings.communityContributionEnabled)
            _InlineNotice(
              message:
                  'Community contribution is disabled. Enable it above to submit reports.',
            )
          else if (_eligibility == null || !_eligibility!.isEligible)
            _InlineNotice(
              message:
                  'Complete a Medium, High, or Critical chat scan/background check first to unlock reporting.',
            )
          else if (_flagParams != null)
            _FlagResult(params: _flagParams!)
          else ...[
            DropdownButtonFormField<String>(
              initialValue: _flagPlatform,
              style: AppTheme.body(13),
              decoration: const InputDecoration(
                labelText: 'Platform',
                prefixIcon:
                    Icon(Icons.devices_outlined, size: 18),
              ),
              items: _platforms
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _flagPlatform = v!),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _flagHandleController,
              style: AppTheme.body(13),
              decoration: const InputDecoration(
                labelText: 'Handle / Username',
                hintText: '@john_crypto88',
                prefixIcon: Icon(Icons.person_outline, size: 18),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _flagPhoneController,
              style: AppTheme.body(13),
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                hintText: '+60123456789',
                prefixIcon: Icon(Icons.phone_outlined, size: 18),
              ),
              keyboardType: TextInputType.phone,
            ),
            if (_eligibility != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: AppTheme.tonalSection(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Eligible source', style: AppTheme.headline(11)),
                    const SizedBox(height: 4),
                    Text(
                      '${_eligibility!.sourceType} · ${_eligibility!.sourceRiskLevel}',
                      style: AppTheme.body(10, color: AppTheme.onSurfaceVariant),
                    ),
                    if (_eligibility!.photoHash != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Photo hash match available for submission.',
                        style: AppTheme.body(
                          10,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text('FLAG TYPE',
                style:
                    AppTheme.label(9, color: AppTheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _flagOptions
                  .map((f) => _ToggleChip(
                        label: f,
                        selected: _selectedFlags.contains(f),
                        onTap: () => setState(() => _selectedFlags
                            .contains(f)
                            ? _selectedFlags.remove(f)
                            : _selectedFlags.add(f)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _flagRegion,
              style: AppTheme.body(13),
              decoration: const InputDecoration(
                labelText: 'Region',
                prefixIcon: Icon(Icons.location_on_outlined, size: 18),
              ),
              items: _regions
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => setState(() => _flagRegion = v!),
            ),
            const SizedBox(height: 16),
            _GradientButton(
              label: 'Submit Report',
              icon: Icons.flag_outlined,
              onPressed: _submitFlag,
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Check Result Widget ───────────────────────────────────────────────────────

class _CheckResult extends ConsumerWidget {
  final CommunityProfileLookupDto params;
  const _CheckResult({required this.params});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(profileCheckProvider(params));
    return async.when(
      loading: () => const LinearProgressIndicator(
          color: AppTheme.primaryContainer),
      error: (_, __) => Text('Check failed.',
          style: AppTheme.body(11, color: AppTheme.onSurfaceVariant)),
      data: (result) => result.flagged
          ? _FlaggedCard(result: result)
          : Container(
              padding: const EdgeInsets.all(12),
              decoration: AppTheme.tonalSection(),
              child: Row(children: [
                const Icon(Icons.check_circle_outline,
                    size: 14, color: Color(0xFF2E7D32)),
                const SizedBox(width: 6),
                Text('No reports found for this profile.',
                    style: AppTheme.body(11,
                        color: const Color(0xFF2E7D32))),
              ]),
            ),
    );
  }
}

class _FlaggedCard extends StatelessWidget {
  final ProfileCheckResult result;
  const _FlaggedCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final tierColor = result.status == 'confirmed'
        ? AppTheme.error
        : result.status == 'flagged'
            ? const Color(0xFFF57F17)
            : const Color(0xFFF9A825);
    final tierBg = result.status == 'confirmed'
        ? AppTheme.errorContainer
        : result.status == 'flagged'
            ? const Color(0xFFFFF3E0)
            : const Color(0xFFFFFDE7);
    final tierLabel = result.status == 'confirmed'
        ? '🔴 CONFIRMED SCAMMER'
        : result.status == 'flagged'
            ? '🟠 FLAGGED BY COMMUNITY'
            : '🟡 REPORTED BY USERS';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: tierBg, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tierLabel,
              style: AppTheme.label(10, color: tierColor)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: [
            _Chip(
                label:
                    '${result.reportCount ?? 0} report${(result.reportCount ?? 0) == 1 ? "" : "s"}',
                color: tierColor,
                bg: tierBg),
            if (result.region != null)
              _Chip(
                  label: result.region!,
                  color: AppTheme.onSurfaceVariant,
                  bg: AppTheme.surfaceContainer),
          ]),
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
                  .map((f) => _Chip(
                      label: f,
                      color: AppTheme.error,
                      bg: AppTheme.errorContainer))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Flag Result Widget ────────────────────────────────────────────────────────

class _FlagResult extends ConsumerWidget {
  final CommunityFlagRequestDto params;
  const _FlagResult({required this.params});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(flagScammerProvider(params));
    return async.when(
      loading: () => const LinearProgressIndicator(
          color: AppTheme.primaryContainer),
      error: (_, __) => Text('Submission failed.',
          style: AppTheme.body(11, color: AppTheme.onSurfaceVariant)),
      data: (result) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.check_circle,
                  size: 16, color: Color(0xFF2E7D32)),
              const SizedBox(width: 6),
              Text('Report submitted',
                  style: AppTheme.headline(12,
                      color: const Color(0xFF2E7D32))),
            ]),
            const SizedBox(height: 4),
            Text(
                'Profile status: ${result.profileStatus} · ${result.totalReports} total reports',
                style: AppTheme.body(11,
                    color: AppTheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
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

class _InlineNotice extends StatelessWidget {
  final String message;
  const _InlineNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.tonalSection(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 15,
            color: AppTheme.primaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTheme.body(11, color: AppTheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleChip(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryContainer : AppTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: AppTheme.label(10,
              color: selected ? Colors.white : AppTheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  const _Chip(
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
