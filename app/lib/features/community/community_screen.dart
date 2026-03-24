import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/models/app_state.dart';
import '../../core/models/community_flag.dart';
import '../../core/models/requests.dart';
import '../../core/state/backend_readiness_provider.dart';
import '../../core/state/shell_navigation.dart';
import '../../core/storage/local_app_state_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/editorial_ui.dart';
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

    // Apply eligibility inline from the intent so we don't depend on a disk read
    if (intent.sourceRiskLevel != null && intent.sourceSessionId != null) {
      _eligibility = CommunityFlagEligibility(
        sourceType: intent.sourceType ?? 'unknown',
        sourceRiskLevel: intent.sourceRiskLevel!,
        sourceSessionId: intent.sourceSessionId!,
        platform: intent.platform,
        handle: intent.handle,
        phone: intent.phone,
        photoHash: intent.photoHash,
      );
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
    if (!_canUseCommunity()) {
      return;
    }
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

    final displayValue = lookup.handle ??
        lookup.phone ??
        lookup.photoHash ??
        _checkController.text.trim();

    setState(() {
      _selectedTab = _CommunityTab.check;
      _checkController.text = displayValue;
      _checkParams = lookup;
    });
  }

  void _submitFlag() {
    if (!_canUseCommunity()) {
      return;
    }
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
      _canAccessFlagTab &&
      _canUseCommunity() &&
      _hasFlagIdentifier &&
      _hasSelectedFlags;

  bool _canUseCommunity() {
    final readiness = ref.read(backendReadinessProvider).valueOrNull;
    return readiness?.capabilityEnabled('community') ?? true;
  }

  String _communityCapabilityMessage() {
    final readiness = ref.read(backendReadinessProvider).valueOrNull;
    if (readiness == null) {
      return 'Community checks are waiting for backend readiness.';
    }
    if (!readiness.isReachable) {
      return 'Start the backend first to check or submit community reports.';
    }
    return 'Community features need SUPABASE_URL and SUPABASE_ANON_KEY configured.';
  }

  String? get _flagValidationMessage {
    if (!_canUseCommunity()) {
      return _communityCapabilityMessage();
    }
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
    ref.watch(backendReadinessProvider);
    final launchIntent = ref.watch(communityLaunchIntentProvider);
    if (launchIntent != null && launchIntent.launchId != _lastHandledLaunchId) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _registerLaunchIntent(launchIntent),
      );
    }

    return EditorialPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EditorialEyebrow(
            label: 'ASEAN NETWORK',
            icon: Icons.public,
          ),
          const SizedBox(height: 18),
          Text(
            'Regional\nScam Shield',
            style: AppTheme.headline(
              42,
              color: AppTheme.primary,
              weight: FontWeight.w800,
              height: 0.94,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'A feed-first community surface for profile lookups, flags, and cross-border scam intelligence. The feed cards are mock-first; the lookup and reporting tools are live.',
            style: AppTheme.body(
              14,
              color: AppTheme.onSurfaceVariant,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
          SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _checkController,
                        decoration: const InputDecoration(
                          hintText: 'Search handles or phone numbers...',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TonalPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      radius: 20,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.filter_list,
                            size: 18,
                            color: AppTheme.onSurface,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Filters',
                            style: AppTheme.headline(13, weight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TonalPanel(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.volunteer_activism_outlined,
                              size: 18,
                              color: AppTheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Community contribution',
                                style: AppTheme.headline(
                                  15,
                                  weight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Switch(
                              value: _settings.communityContributionEnabled,
                              onChanged: _toggleContribution,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (!_canUseCommunity()) ...[
                  const SizedBox(height: 10),
                  Text(
                    _communityCapabilityMessage(),
                    style: AppTheme.body(
                      12,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          const EditorialSectionTitle(
            title: 'Regional intelligence feed',
            subtitle: 'Live community reports ordered by most recent activity.',
          ),
          const SizedBox(height: 14),
          Consumer(
            builder: (context, ref, _) {
              final feedAsync = ref.watch(communityFeedProvider);
              return feedAsync.when(
                loading: () => const LinearProgressIndicator(
                  color: AppTheme.primaryContainer,
                  minHeight: 5,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                error: (_, __) => const TonalPanel(
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, size: 18, color: AppTheme.error),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Could not load community reports',
                          style: TextStyle(
                            color: AppTheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                data: (entries) => entries.isEmpty
                    ? const TonalPanel(
                        child: Text(
                          'No community reports yet.',
                          style: TextStyle(fontSize: 12),
                        ),
                      )
                    : Column(
                        children: entries
                            .map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _FeedCard(entry: e),
                              ),
                            )
                            .toList(),
                      ),
              );
            },
          ),
          const SizedBox(height: 12),
          const _MockThreatCard(),
          const SizedBox(height: 22),
          const EditorialSectionTitle(
            title: 'Community tools',
            subtitle:
                'Real lookup and reporting flows inside the new feed-first surface.',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CommunityTabButton(
                  label: 'Check Profile',
                  selected: _selectedTab == _CommunityTab.check,
                  onTap: () => _selectTab(_CommunityTab.check),
                ),
              ),
              const SizedBox(width: 10),
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
          if (!_loadingState && !_canAccessFlagTab) ...[
            const SizedBox(height: 12),
            _InlineNotice(message: _flagLockMessage),
          ],
          const SizedBox(height: 14),
          SurfacePanel(
            child: _selectedTab == _CommunityTab.check
                ? _buildCheckTab()
                : _buildFlagTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckTab() {
    final canUseCommunity = _canUseCommunity();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CHECK PROFILE',
          style: AppTheme.label(11, weight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _checkController,
                decoration: const InputDecoration(
                  hintText: 'Handle or phone number',
                  prefixIcon: Icon(Icons.search_outlined),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 132,
              child: GradientCtaButton(
                label: 'Check',
                icon: Icons.arrow_forward,
                onPressed: _runCheck,
                enabled: canUseCommunity,
                compact: true,
              ),
            ),
          ],
        ),
        if (!canUseCommunity) ...[
          const SizedBox(height: 10),
          Text(
            _communityCapabilityMessage(),
            style: AppTheme.body(12, color: AppTheme.onSurfaceVariant),
          ),
        ],
        if (_checkParams != null) ...[
          const SizedBox(height: 16),
          _CheckResult(params: _checkParams!),
        ],
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FLAG SCAMMER',
          style: AppTheme.label(11, weight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _flagPlatform,
          decoration: const InputDecoration(
            labelText: 'Platform',
            prefixIcon: Icon(Icons.devices_outlined),
          ),
          items: _platforms
              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
              .toList(),
          onChanged: (v) => setState(() => _flagPlatform = v!),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _flagHandleController,
          decoration: const InputDecoration(
            labelText: 'Handle / Username',
            hintText: '@john_crypto88',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _flagPhoneController,
          decoration: const InputDecoration(
            labelText: 'Phone',
            hintText: '+60123456789',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          keyboardType: TextInputType.phone,
        ),
        if (_eligibility != null) ...[
          const SizedBox(height: 12),
          TonalPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Eligible source',
                  style: AppTheme.headline(16, weight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_eligibility!.sourceType} · ${_eligibility!.sourceRiskLevel}',
                  style: AppTheme.body(
                    12,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
                if ((_launchPhotoHash ?? _eligibility!.photoHash) != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Photo hash evidence is available for this report.',
                    style: AppTheme.body(
                      12,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Text(
          'FLAG TYPE',
          style: AppTheme.label(11, weight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _flagOptions
              .map(
                (flag) => _ToggleChip(
                  label: flag,
                  selected: _selectedFlags.contains(flag),
                  onTap: () => setState(
                    () => _selectedFlags.contains(flag)
                        ? _selectedFlags.remove(flag)
                        : _selectedFlags.add(flag),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _flagRegion,
          decoration: const InputDecoration(
            labelText: 'Region',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
          items: _regions
              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
              .toList(),
          onChanged: (v) => setState(() => _flagRegion = v!),
        ),
        const SizedBox(height: 16),
        GradientCtaButton(
          label: 'Submit Report',
          icon: Icons.flag_outlined,
          onPressed: _submitFlag,
          enabled: _canSubmitFlag,
        ),
        if (_flagValidationMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            _flagValidationMessage!,
            style: AppTheme.body(12, color: AppTheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _CheckResult extends ConsumerWidget {
  const _CheckResult({required this.params});

  final CommunityProfileLookupDto params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(profileCheckProvider(params));
    return async.when(
      loading: () => const LinearProgressIndicator(
        color: AppTheme.primaryContainer,
        minHeight: 5,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      error: (error, _) => Text(
        formatApiError(error, fallbackMessage: 'Check failed.'),
        style: AppTheme.body(12, color: AppTheme.onSurfaceVariant),
      ),
      data: (result) => result.flagged
          ? _FlaggedCard(result: result, params: params)
          : const TonalPanel(
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: AppTheme.success,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No reports found for this profile.',
                      style: TextStyle(
                        color: AppTheme.success,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _FlaggedCard extends StatelessWidget {
  const _FlaggedCard({
    required this.result,
    required this.params,
  });

  final ProfileCheckResult result;
  final CommunityProfileLookupDto params;

  @override
  Widget build(BuildContext context) {
    final status = (result.status ?? 'reported').toUpperCase();
    final color = AppTheme.severityColor(status);
    final background = AppTheme.severityBackground(status);
    final handle = params.handle ?? params.phone ?? 'unknown_profile';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TonalPanel(
          color: background,
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Flagged profile detected in the community database.',
                  style: AppTheme.headline(
                    15,
                    color: color,
                    weight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.errorContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: AppTheme.error),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Exercise extreme caution when interacting with this profile.',
                  style: TextStyle(
                    color: AppTheme.error,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        GlassPanel(
          radius: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.person_off_outlined,
                      size: 38,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RiskBadge(label: status, color: color, background: background),
                        const SizedBox(height: 12),
                        Text(
                          handle.startsWith('@') ? handle : '@$handle',
                          style: AppTheme.headline(
                            26,
                            color: AppTheme.primary,
                            weight: FontWeight.w800,
                          ),
                        ),
                        if (result.region != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            result.region!,
                            style: AppTheme.label(10, weight: FontWeight.w700),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.flag_outlined,
                      value: '${result.reportCount ?? 0}',
                      label: 'Reports',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.calendar_today_outlined,
                      value: result.firstReported ?? '–',
                      label: 'First seen',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.public,
                      value: result.region ?? '–',
                      label: 'Region',
                    ),
                  ),
                ],
              ),
              if (result.commonFlags != null &&
                  result.commonFlags!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: result.commonFlags!
                      .map((flag) => _InfoChip(label: flag))
                      .toList(),
                ),
              ],
              if (result.photoHash != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Photo hash: ${result.photoHash!.substring(0, result.photoHash!.length > 8 ? 8 : result.photoHash!.length)}...',
                  style: AppTheme.label(
                    10,
                    color: AppTheme.onSurfaceVariant,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FlagResult extends ConsumerWidget {
  const _FlagResult({
    required this.params,
    required this.onCheckProfile,
  });

  final CommunityFlagRequestDto params;
  final VoidCallback onCheckProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(flagScammerProvider(params));
    return async.when(
      loading: () => const LinearProgressIndicator(
        color: AppTheme.primaryContainer,
        minHeight: 5,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      error: (error, _) => Text(
        formatApiError(error, fallbackMessage: 'Submission failed.'),
        style: AppTheme.body(12, color: AppTheme.onSurfaceVariant),
      ),
      data: (result) => TonalPanel(
        color: AppTheme.successContainer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppTheme.success,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  'Report submitted',
                  style: AppTheme.headline(
                    16,
                    color: AppTheme.success,
                    weight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Profile status: ${result.profileStatus} · ${result.totalReports} total reports',
              style: AppTheme.body(12, color: AppTheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
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
  const _CommunityTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = !enabled
        ? AppTheme.surfaceContainer
        : selected
            ? null
            : AppTheme.surfaceLowest;
    final foreground = !enabled
        ? AppTheme.onSurfaceVariant
        : selected
            ? Colors.white
            : AppTheme.onSurface;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: selected ? AppTheme.gradient : null,
          color: background,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : AppTheme.outlineVariant.withValues(alpha: 0.25),
          ),
          boxShadow: selected ? [AppTheme.ambientShadow] : null,
        ),
        child: Center(
          child: Text(
            label,
            style: AppTheme.headline(
              14,
              color: foreground,
              weight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return TonalPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 18,
            color: AppTheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTheme.body(
                12,
                color: AppTheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? AppTheme.gradient : null,
          color: selected ? null : AppTheme.primaryFixed.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppTheme.label(
            10,
            color: foreground,
            weight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}


class _MockThreatCard extends StatelessWidget {
  const _MockThreatCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: AppTheme.gradientBox(radius: 28),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MockTag(label: 'Weekly mock'),
          const SizedBox(height: 12),
          Text(
            'Weekly ASEAN Threat Assessment',
            style: AppTheme.headline(
              24,
              color: Colors.white,
              weight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Cross-border crypto romance scams are trending upward this week, with high-pressure money requests and investment coercion leading the report mix.',
            style: AppTheme.body(
              13,
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Read Report →'),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTheme.label(10, weight: FontWeight.w700),
      ),
    );
  }
}

Color _feedStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'confirmed':
      return AppTheme.error;
    case 'flagged':
      return const Color(0xFFF57F17);
    default:
      return const Color(0xFF2E7D32);
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.entry});

  final CommunityFeedEntry entry;

  @override
  Widget build(BuildContext context) {
    final statusColor = _feedStatusColor(entry.status ?? 'reported');
    final statusLabel = (entry.status ?? 'reported').toUpperCase();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.surfaceCard(radius: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_off_outlined, size: 18, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.handle ?? 'Unknown',
                  style: AppTheme.headline(14, weight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (entry.region != null) ...[
                      _InfoChip(label: entry.region!),
                      const SizedBox(width: 6),
                    ],
                    RiskBadge(
                      label: statusLabel,
                      color: statusColor,
                      background: statusColor.withValues(alpha: 0.12),
                    ),
                  ],
                ),
                if (entry.lastReported != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    entry.lastReported!,
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
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: AppTheme.surfaceCard(radius: 16),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTheme.headline(13, weight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTheme.label(9, letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }
}
