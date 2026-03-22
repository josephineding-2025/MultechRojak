// Owner: Member 3
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/community_flag.dart';
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
  Map<String, String>? _checkParams;

  // ── Flag Scammer ──────────────────────────────────────────────────────────
  final _flagHandleController = TextEditingController();
  final _flagPhoneController = TextEditingController();
  String _flagPlatform = 'Telegram';
  String _flagRegion = 'MY';
  final Set<String> _selectedFlags = {};
  Map<String, dynamic>? _flagParams;

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
  void dispose() {
    _checkController.dispose();
    _flagHandleController.dispose();
    _flagPhoneController.dispose();
    super.dispose();
  }

  void _runCheck() {
    final q = _checkController.text.trim();
    if (q.isEmpty) return;
    setState(() => _checkParams = {
          if (q.startsWith('+') || RegExp(r'^\d').hasMatch(q))
            'phone': q
          else
            'handle': q,
        });
  }

  void _submitFlag() {
    final handle = _flagHandleController.text.trim();
    if (handle.isEmpty) return;
    setState(() => _flagParams = {
          'platform': _flagPlatform,
          'handle': handle,
          if (_flagPhoneController.text.trim().isNotEmpty)
            'phone': _flagPhoneController.text.trim(),
          'flags': _selectedFlags.toList(),
          'region': _flagRegion,
        });
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
          if (_flagParams != null)
            _FlagResult(params: _flagParams!)
          else ...[
            DropdownButtonFormField<String>(
              value: _flagPlatform,
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
              value: _flagRegion,
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
  final Map<String, String> params;
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
  final Map<String, dynamic> params;
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
