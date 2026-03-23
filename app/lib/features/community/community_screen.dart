// Owner: Member 3
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_error.dart';
import '../../core/models/app_state.dart';
import '../../core/models/community_flag.dart';
import '../../core/models/requests.dart';
import '../../core/state/shell_navigation.dart';
import '../../core/storage/local_app_state_store.dart';
import '../../core/theme/app_theme.dart';
import 'community_provider.dart';

enum _CommunityTab { check, flag }

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  final _checkController = TextEditingController();
  CommunityProfileLookupDto? _checkParams;

  final _flagHandleController = TextEditingController();
  final _flagPhoneController = TextEditingController();
  String _flagPlatform = 'Telegram';
  String _flagRegion = 'MY';
  final Set<String> _selectedFlags = {};
  CommunityFlagRequestDto? _flagParams;
  AppSettings _settings = const AppSettings();
  CommunityFlagEligibility? _eligibility;
  bool _loadingState = true;
  _CommunityTab _selectedTab = _CommunityTab.check;
  CommunityLaunchIntent? _pendingLaunchIntent;
  int? _lastHandledLaunchId;
  String? _launchPhotoHash;

  static const _platforms = [
    'Telegram',
    'WhatsApp',
    'Instagram',
    'X',
    'Dating App',
    'Other',
  ];
  static const _regions = ['MY', 'SG', 'PH', 'ID', 'TH', 'VN', 'Other'];
  static const _flagOptions = [
    'money request',
    'fake investment',
    'identity inconsistency',
    'catfishing',
    'other',
  ];

  bool get _canAccessFlagTab =>
      !_loadingState &&
      _settings.communityContributionEnabled &&
      (_eligibility?.isEligible ?? false);

  String get _flagLockMessage {
    if (!_settings.communityContributionEnabled) {
      return 'Community contribution is disabled. Enable it above to submit reports.';
    }
    return 'Complete a chat scan or background check first to unlock reporting.';
  }

  @override
  void initState() {
    super.initState();
    _flagHandleController.addListener(_onFlagFieldChanged);
    _flagPhoneController.addListener(_onFlagFieldChanged);
    _loadLocalState();
  }

  @override
  void dispose() {
    _flagHandleController.removeListener(_onFlagFieldChanged);
    _flagPhoneController.removeListener(_onFlagFieldChanged);
    _checkController.dispose();
    _flagHandleController.dispose();
    _flagPhoneController.dispose();
    super.dispose();
  }

  void _onFlagFieldChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _loadLocalState() async {
    final settings = await LocalAppStateStore.instance.loadSettings();
    final eligibility =
        await LocalAppStateStore.instance.loadCommunityFlagEligibility();
    if (!mounted) {
      return;
    }

    setState(() {
      _settings = settings;
      _eligibility = eligibility;
      _loadingState = false;
      _applyEligibilityPrefill(eligibility);
      if (!_canAccessFlagTab && _selectedTab == _CommunityTab.flag) {
        _selectedTab = _CommunityTab.check;
      }
    });

    _applyPendingLaunchIntentSelection();
  }

  void _applyEligibilityPrefill(CommunityFlagEligibility? eligibility) {
    if (eligibility == null) {
      return;
    }
    if (_flagHandleController.text.isEmpty && eligibility.handle != null) {
      _flagHandleController.text = eligibility.handle!;
    }
    if (_flagPhoneController.text.isEmpty && eligibility.phone != null) {
      _flagPhoneController.text = eligibility.phone!;
    }
    if (eligibility.platform != null) {
      _flagPlatform = _normalizePlatform(eligibility.platform);
    }
  }

  String _normalizePlatform(String? platform) {
    if (platform == null) {
      return _flagPlatform;
    }
    return _platforms.contains(platform) ? platform : 'Other';
  }

  Future<void> _toggleContribution(bool value) async {
    final nextSettings = AppSettings(communityContributionEnabled: value);
    await LocalAppStateStore.instance.saveSettings(nextSettings);
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = nextSettings;
      if (!_canAccessFlagTab && _selectedTab == _CommunityTab.flag) {
        _selectedTab = _CommunityTab.check;
      }
    });
  }

  void _registerLaunchIntent(CommunityLaunchIntent intent) {
    if (_lastHandledLaunchId == intent.launchId) {
      return;
    }

    _lastHandledLaunchId = intent.launchId;
    _pendingLaunchIntent = intent;
    _launchPhotoHash = intent.photoHash ?? _launchPhotoHash;

    if (intent.platform != null) {
      _flagPlatform = _normalizePlatform(intent.platform);
    }
    if (intent.handle != null && intent.handle!.trim().isNotEmpty) {
      _flagHandleController.text = intent.handle!;
    }
    if (intent.phone != null && intent.phone!.trim().isNotEmpty) {
      _flagPhoneController.text = intent.phone!;
    }

    ref.read(communityLaunchIntentProvider.notifier).state = null;
    _applyPendingLaunchIntentSelection();
  }

  void _applyPendingLaunchIntentSelection() {
    if (!mounted || _loadingState || _pendingLaunchIntent == null) {
      return;
    }

    final intent = _pendingLaunchIntent!;
    _pendingLaunchIntent = null;

    setState(() {
      _flagParams = null;
      if (intent.mode == CommunityLaunchMode.flag && _canAccessFlagTab) {
        _selectedTab = _CommunityTab.flag;
      } else {
        _selectedTab = _CommunityTab.check;
      }
    });
  }

  void _selectTab(_CommunityTab tab) {
    if (tab == _CommunityTab.flag && !_canAccessFlagTab) {
      return;
    }

    setState(() {
      _selectedTab = tab;
      if (tab == _CommunityTab.flag) {
        _flagParams = null;
      }
    });
  }

  void _runCheck() {
    final q = _checkController.text.trim();
    if (q.isEmpty) {
      return;
    }

    _runCheckWithLookup(
      CommunityProfileLookupDto(
        phone: q.startsWith('+') || RegExp(r'^\d').hasMatch(q) ? q : null,
        handle: q.startsWith('+') || RegExp(r'^\d').hasMatch(q) ? null : q,
      ),
    );
  }

  void _runCheckWithLookup(CommunityProfileLookupDto lookup) {
    if (!lookup.hasIdentifier) {
      return;
    }

    LocalAppStateStore.instance.saveLastCommunityLookup(
      LastCommunityLookup(
        handle: lookup.handle,
        phone: lookup.phone,
      ),
    );

    final displayValue =
        lookup.handle ?? lookup.phone ?? lookup.photoHash ?? _checkController.text.trim();

    setState(() {
      _selectedTab = _CommunityTab.check;
      _checkController.text = displayValue;
      _checkParams = lookup;
    });
  }

  void _submitFlag() {
    if (!_canAccessFlagTab || _eligibility == null) {
      return;
    }

    final handle = _flagHandleController.text.trim();
    final phone = _flagPhoneController.text.trim();
    final effectiveHandle = handle.isNotEmpty ? handle : _eligibility!.handle;
    final effectivePhone = phone.isNotEmpty ? phone : _eligibility!.phone;
    final photoHash = _launchPhotoHash ?? _eligibility!.photoHash;

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

  void _checkCurrentFlagProfile() {
    final handle = _flagHandleController.text.trim();
    final phone = _flagPhoneController.text.trim();
    final effectiveHandle = handle.isNotEmpty ? handle : _eligibility?.handle;
    final effectivePhone = phone.isNotEmpty ? phone : _eligibility?.phone;
    final photoHash = _launchPhotoHash ?? _eligibility?.photoHash;

    _runCheckWithLookup(
      CommunityProfileLookupDto(
        handle: effectiveHandle,
        phone: effectivePhone,
        photoHash: photoHash,
      ),
    );
  }

  String? get _effectiveFlagHandle {
    final handle = _flagHandleController.text.trim();
    if (handle.isNotEmpty) {
      return handle;
    }
    final saved = _eligibility?.handle?.trim();
    if (saved != null && saved.isNotEmpty) {
      return saved;
    }
    return null;
  }

  String? get _effectiveFlagPhone {
    final phone = _flagPhoneController.text.trim();
    if (phone.isNotEmpty) {
      return phone;
    }
    final saved = _eligibility?.phone?.trim();
    if (saved != null && saved.isNotEmpty) {
      return saved;
    }
    return null;
  }

  String? get _effectiveFlagPhotoHash {
    final hash = (_launchPhotoHash ?? _eligibility?.photoHash)?.trim();
    if (hash != null && hash.isNotEmpty) {
      return hash;
    }
    return null;
  }

  bool get _hasFlagIdentifier =>
      _effectiveFlagHandle != null ||
      _effectiveFlagPhone != null ||
      _effectiveFlagPhotoHash != null;

  bool get _hasSelectedFlags => _selectedFlags.isNotEmpty;

  bool get _canSubmitFlag =>
      _canAccessFlagTab && _hasFlagIdentifier && _hasSelectedFlags;

  String? get _flagValidationMessage {
    if (!_hasFlagIdentifier && !_hasSelectedFlags) {
      return 'Enter a handle/phone or use a saved photo hash, then select at least one flag type.';
    }
    if (!_hasFlagIdentifier) {
      return 'Enter at least one identifier: handle, phone, or photo hash-backed scan result.';
    }
    if (!_hasSelectedFlags) {
      return 'Select at least one flag type before submitting.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final launchIntent = ref.watch(communityLaunchIntentProvider);
    if (launchIntent != null &&
        launchIntent.launchId != _lastHandledLaunchId) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _registerLaunchIntent(launchIntent),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.group_outlined,
                size: 18,
                color: AppTheme.primaryContainer,
              ),
              const SizedBox(width: 8),
              Text('Community Circle', style: AppTheme.headline(15)),
            ],
          ),
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
                      Text(
                        'Community contribution',
                        style: AppTheme.headline(11),
                      ),
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
          Row(
            children: [
              Expanded(
                child: _CommunityTabButton(
                  label: 'Check Profile',
                  selected: _selectedTab == _CommunityTab.check,
                  onTap: () => _selectTab(_CommunityTab.check),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CommunityTabButton(
                  label: 'Flag Scammer',
                  selected: _selectedTab == _CommunityTab.flag,
                  enabled: _canAccessFlagTab,
                  onTap: () => _selectTab(_CommunityTab.flag),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_loadingState && !_canAccessFlagTab)
            _InlineNotice(message: _flagLockMessage),
          if (!_loadingState && !_canAccessFlagTab) const SizedBox(height: 12),
          if (_selectedTab == _CommunityTab.check)
            _buildCheckTab()
          else
            _buildFlagTab(),
        ],
      ),
    );
  }

  Widget _buildCheckTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'CHECK PROFILE',
          style: AppTheme.label(9, color: AppTheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _checkController,
                style: AppTheme.body(13),
                decoration: const InputDecoration(
                  hintText: 'Handle or phone number',
                  prefixIcon: Icon(Icons.search_outlined, size: 18),
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
                  child: Text(
                    'Check',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_checkParams != null) _CheckResult(params: _checkParams!),
      ],
    );
  }

  Widget _buildFlagTab() {
    if (_loadingState) {
      return const LinearProgressIndicator(color: AppTheme.primaryContainer);
    }
    if (!_canAccessFlagTab) {
      return _InlineNotice(message: _flagLockMessage);
    }
    if (_flagParams != null) {
      return _FlagResult(
        params: _flagParams!,
        onCheckProfile: _checkCurrentFlagProfile,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'FLAG SCAMMER',
          style: AppTheme.label(9, color: AppTheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _flagPlatform,
          style: AppTheme.body(13),
          decoration: const InputDecoration(
            labelText: 'Platform',
            prefixIcon: Icon(Icons.devices_outlined, size: 18),
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
                if ((_launchPhotoHash ?? _eligibility!.photoHash) != null) ...[
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
        Text(
          'FLAG TYPE',
          style: AppTheme.label(9, color: AppTheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _flagOptions
              .map(
                (f) => _ToggleChip(
                  label: f,
                  selected: _selectedFlags.contains(f),
                  onTap: () => setState(
                    () => _selectedFlags.contains(f)
                        ? _selectedFlags.remove(f)
                        : _selectedFlags.add(f),
                  ),
                ),
              )
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
          enabled: _canSubmitFlag,
        ),
        if (_flagValidationMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _flagValidationMessage!,
            style: AppTheme.body(11, color: AppTheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _CheckResult extends ConsumerWidget {
  final CommunityProfileLookupDto params;
  const _CheckResult({required this.params});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(profileCheckProvider(params));
    return async.when(
      loading: () =>
          const LinearProgressIndicator(color: AppTheme.primaryContainer),
      error: (error, _) => Text(
        formatApiError(error, fallbackMessage: 'Check failed.'),
        style: AppTheme.body(11, color: AppTheme.onSurfaceVariant),
      ),
      data: (result) => result.flagged
          ? _FlaggedCard(result: result)
          : Container(
              padding: const EdgeInsets.all(12),
              decoration: AppTheme.tonalSection(),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 14,
                    color: Color(0xFF2E7D32),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'No reports found for this profile.',
                    style: AppTheme.body(
                      11,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
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
        color: tierBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tierLabel, style: AppTheme.label(10, color: tierColor)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _Chip(
                label:
                    '${result.reportCount ?? 0} report${(result.reportCount ?? 0) == 1 ? "" : "s"}',
                color: tierColor,
                bg: tierBg,
              ),
              if (result.region != null)
                _Chip(
                  label: result.region!,
                  color: AppTheme.onSurfaceVariant,
                  bg: AppTheme.surfaceContainer,
                ),
            ],
          ),
          if (result.firstReported != null) ...[
            const SizedBox(height: 4),
            Text(
              'First reported: ${result.firstReported}',
              style: AppTheme.label(10),
            ),
          ],
          if (result.commonFlags != null && result.commonFlags!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: result.commonFlags!
                  .map(
                    (f) => _Chip(
                      label: f,
                      color: AppTheme.error,
                      bg: AppTheme.errorContainer,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _FlagResult extends ConsumerWidget {
  final CommunityFlagRequestDto params;
  final VoidCallback onCheckProfile;

  const _FlagResult({
    required this.params,
    required this.onCheckProfile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(flagScammerProvider(params));
    return async.when(
      loading: () =>
          const LinearProgressIndicator(color: AppTheme.primaryContainer),
      error: (error, _) => Text(
        formatApiError(error, fallbackMessage: 'Submission failed.'),
        style: AppTheme.body(11, color: AppTheme.onSurfaceVariant),
      ),
      data: (result) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 16,
                  color: Color(0xFF2E7D32),
                ),
                const SizedBox(width: 6),
                Text(
                  'Report submitted',
                  style: AppTheme.headline(
                    12,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Profile status: ${result.profileStatus} · ${result.totalReports} total reports',
              style: AppTheme.body(11, color: AppTheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onCheckProfile,
              child: const Text('Check This Profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _CommunityTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final background = !enabled
        ? AppTheme.surfaceContainer
        : selected
            ? AppTheme.primaryContainer
            : AppTheme.surface;
    final foreground = !enabled
        ? AppTheme.onSurfaceVariant
        : selected
            ? Colors.white
            : AppTheme.onSurface;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primaryContainer : AppTheme.surfaceContainer,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;

  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: Container(
        height: 46,
        decoration: enabled
            ? AppTheme.gradientBox(radius: 12)
            : BoxDecoration(
                color: AppTheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: enabled ? Colors.white : AppTheme.onSurfaceVariant,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: enabled ? Colors.white : AppTheme.onSurfaceVariant,
              ),
            ),
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

  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryContainer
              : AppTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: AppTheme.label(
            10,
            color: selected ? Colors.white : AppTheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;

  const _Chip({
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: AppTheme.label(10, color: color)),
    );
  }
}
