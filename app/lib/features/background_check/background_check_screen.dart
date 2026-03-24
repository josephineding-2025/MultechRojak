import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/models/app_state.dart';
import '../../core/models/background_check_result.dart';
import '../../core/models/community_flag.dart';
import '../../core/models/requests.dart';
import '../../core/state/backend_readiness_provider.dart';
import '../../core/state/shell_navigation.dart';
import '../../core/storage/local_app_state_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/editorial_ui.dart';
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
  String _selectedChipLabel = 'X'; // tracks which chip is visually active
  bool _showManualFields = false;

  BackgroundCheckRequestDto? _params;
  BackgroundCheckStreamRequestDto? _streamParams;
  final List<BackgroundCheckEvent> _streamEvents = [];
  String? _lastEligibilitySessionId;
  String? _selectedPhotoB64;
  String? _selectedPhotoName;

  // Chip display label → platform value mapping
  static const _platformChips = [
    ('Tinder', 'Dating App'),
    ('WhatsApp', 'WhatsApp'),
    ('Instagram', 'Instagram'),
    ('Bumble', 'Dating App'),
    ('Telegram', 'Telegram'),
    ('X', 'X'),
    ('Other', 'Other'),
  ];

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    if (!_canRunBackgroundCheck()) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final url = _urlController.text.trim();
    final username = _usernameController.text.trim();
    final phone = _phoneController.text.trim();

    if (url.isNotEmpty) {
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
      setState(() {
        _streamParams = null;
        _params = BackgroundCheckRequestDto(
          username: username,
          platform: _selectedPlatform,
          phone: phone.isNotEmpty ? phone : null,
          photoB64: _selectedPhotoB64,
        );
      });
    }
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    setState(() {
      _selectedPhotoB64 = base64Encode(file.bytes!);
      _selectedPhotoName = file.name;
    });
  }

  void _clearPhoto() {
    setState(() {
      _selectedPhotoB64 = null;
      _selectedPhotoName = null;
    });
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
    ref.watch(backendReadinessProvider);

    if (_streamParams != null) {
      final stream = ref.watch(backgroundCheckStreamProvider(_streamParams!));
      stream.whenData((event) {
        if (!_streamEvents.any(
          (e) => e.step == event.step && e.message == event.message,
        )) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _streamEvents.add(event));
            }
          });
        }
      });

      final latestResult = _streamEvents
          .where((e) => e.step == CheckStep.complete && e.result != null)
          .map((e) => e.result!)
          .lastOrNull;

      return EditorialPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EditorialEyebrow(
              label: 'LIVE DOSSIER',
              icon: Icons.travel_explore,
            ),
            const SizedBox(height: 18),
            Text(
              'Open-source intelligence\nin progress.',
              style: AppTheme.headline(
                34,
                color: AppTheme.primary,
                weight: FontWeight.w800,
                height: 0.98,
              ),
            ),
            const SizedBox(height: 20),
            _buildStreamProgress(),
            if (latestResult != null) ...[
              const SizedBox(height: 18),
              _buildResult(latestResult),
            ],
          ],
        ),
      );
    }

    final result =
        _params != null ? ref.watch(backgroundCheckProvider(_params!)) : null;
    return EditorialPage(
      child: result == null
          ? _buildForm()
          : result.when(
              data: _buildResult,
              loading: _buildLoading,
              error: _buildError,
            ),
    );
  }

  bool _canRunBackgroundCheck() {
    final readiness = ref.read(backendReadinessProvider).valueOrNull;
    return readiness?.capabilityEnabled('background_check') ?? true;
  }

  String _backgroundCheckCapabilityMessage() {
    final readiness = ref.read(backendReadinessProvider).valueOrNull;
    if (readiness == null) {
      return 'Background check is waiting for backend readiness.';
    }
    if (!readiness.isReachable) {
      return 'Start the backend first to run profile checks.';
    }
    final missing = readiness.missingCoreEnv.where(
      (name) =>
          name == 'OPENROUTER_API_KEY' ||
          name == 'SERPAPI_KEY' ||
          name == 'NUMVERIFY_API_KEY',
    );
    if (missing.isEmpty) {
      return 'Background check is not ready yet.';
    }
    return 'Background check needs ${missing.join(', ')} configured.';
  }

  Widget _buildForm() {
    final canRunBackgroundCheck = _canRunBackgroundCheck();

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EditorialEyebrow(
            label: 'OPEN-SOURCE INTELLIGENCE',
            icon: Icons.manage_search,
          ),
          const SizedBox(height: 18),
          Text(
            'Vigilance by\nIntelligence.',
            style: AppTheme.headline(
              42,
              color: AppTheme.primary,
              weight: FontWeight.w800,
              height: 0.94,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Run a discreet background check against public signals, account patterns, phone metadata, and cross-platform consistency.',
            style: AppTheme.body(
              14,
              color: AppTheme.onSurfaceVariant,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 24),
          SurfacePanel(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PLATFORM IDENTITY',
                  style: AppTheme.label(11, weight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'Profile URL',
                    hintText: 'https://instagram.com/john_doe',
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () =>
                      setState(() => _showManualFields = !_showManualFields),
                  child: Row(
                    children: [
                      Icon(
                        _showManualFields
                            ? Icons.remove_circle_outline
                            : Icons.add_circle_outline,
                        size: 18,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Reveal manual fields',
                        style: AppTheme.headline(
                          14,
                          color: AppTheme.primary,
                          weight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_showManualFields) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username / Handle',
                      hintText: '@john_doe123',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) {
                      final url = _urlController.text.trim();
                      if (url.isEmpty && (v == null || v.trim().isEmpty)) {
                        return 'Enter a URL or username';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'PLATFORM',
                    style: AppTheme.label(10, weight: FontWeight.w800, letterSpacing: 1.8),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _platformChips.map((chip) {
                      final chipLabel = chip.$1;
                      final chipValue = chip.$2;
                      final selected = _selectedChipLabel == chipLabel;
                      return FilterChip(
                        label: Text(
                          chipLabel,
                          style: AppTheme.label(
                            11,
                            color: selected ? Colors.white : AppTheme.onSurface,
                            weight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                        selected: selected,
                        onSelected: (_) => setState(() {
                          _selectedChipLabel = chipLabel;
                          _selectedPlatform = chipValue;
                        }),
                        selectedColor: AppTheme.primaryContainer,
                        backgroundColor: AppTheme.surfaceContainer,
                        checkmarkColor: Colors.white,
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      hintText: '+60123456789',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ],
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _pickPhoto,
                  child: TonalPanel(
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryFixed.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _selectedPhotoB64 != null
                                ? Icons.check_circle_outline
                                : Icons.add_photo_alternate_outlined,
                            size: 20,
                            color: _selectedPhotoB64 != null
                                ? AppTheme.success
                                : AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedPhotoName != null
                                    ? _selectedPhotoName!
                                    : 'Upload profile photo',
                                style: AppTheme.headline(
                                  13,
                                  weight: FontWeight.w700,
                                  color: _selectedPhotoB64 != null
                                      ? AppTheme.onSurface
                                      : AppTheme.primary,
                                ),
                              ),
                              Text(
                                _selectedPhotoB64 != null
                                    ? 'Tap to change · pHash will be computed on scan'
                                    : 'Optional — enables reverse image search',
                                style: AppTheme.body(
                                  11,
                                  color: AppTheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_selectedPhotoB64 != null)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            color: AppTheme.onSurfaceVariant,
                            onPressed: _clearPhoto,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                GradientCtaButton(
                  label: 'Run AI Background Check',
                  icon: Icons.travel_explore,
                  onPressed: _onSubmit,
                  enabled: canRunBackgroundCheck,
                ),
                if (!canRunBackgroundCheck) ...[
                  const SizedBox(height: 12),
                  Text(
                    _backgroundCheckCapabilityMessage(),
                    style: AppTheme.body(
                      12,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          TonalPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 18,
                      color: AppTheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Privacy Guarantee',
                      style: AppTheme.headline(16, weight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Zero-storage by design. Handles, URLs, and phone identifiers are processed for the report flow and not persisted as raw investigation input.',
                  style: AppTheme.body(
                    12,
                    color: AppTheme.onSurfaceVariant,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HOW IT WORKS',
                  style: AppTheme.label(11, weight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                const _StepRow(
                  index: 1,
                  body:
                      'Scrape public profile signals and parse bio-based identifiers.',
                ),
                const SizedBox(height: 10),
                const _StepRow(
                  index: 2,
                  body:
                      'Cross-check username, phone, and photo indicators across open sources.',
                ),
                const SizedBox(height: 10),
                const _StepRow(
                  index: 3,
                  body:
                      'Generate a local dossier with a consistency score and community match context.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SurfacePanel(
            child: Row(
              children: [
                const MockTag(label: 'Mock CTA'),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Talk to a Security Concierge',
                        style: AppTheme.headline(18, weight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Reserved for a future assisted review flow. The CTA is intentionally styled now without adding unsupported behavior.',
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
          ),
        ],
      ),
    );
  }

  Widget _buildStreamProgress() {
    final isComplete = _streamEvents.any((e) => e.step == CheckStep.complete);
    final hasError = _streamEvents.any((e) => e.step == CheckStep.error);

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Live Analysis',
                style: AppTheme.headline(18, weight: FontWeight.w800),
              ),
              const Spacer(),
              if (isComplete || hasError)
                TextButton(
                  onPressed: _reset,
                  child: const Text('New Search'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_streamEvents.isEmpty)
            const LinearProgressIndicator(
              color: AppTheme.primaryContainer,
              minHeight: 6,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            )
          else ...[
            ..._streamEvents.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _StreamEventRow(event: e),
                )),
            if (!isComplete && !hasError)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: LinearProgressIndicator(
                  color: AppTheme.primaryContainer,
                  minHeight: 6,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: GlassPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EditorialEyebrow(label: 'PROCESSING', icon: Icons.radar),
            const SizedBox(height: 16),
            Text(
              'Running intelligence checks',
              style: AppTheme.headline(
                26,
                color: AppTheme.primary,
                weight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            const CircularProgressIndicator(
              color: AppTheme.primaryContainer,
              strokeWidth: 2.8,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(Object error, StackTrace? _) {
    return Center(
      child: GlassPanel(
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
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Check failed',
              style: AppTheme.headline(
                24,
                color: AppTheme.error,
                weight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              formatApiError(error, fallbackMessage: 'Check failed.'),
              textAlign: TextAlign.center,
              style: AppTheme.body(
                13,
                color: AppTheme.onSurfaceVariant,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: _reset,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  String _buildCaseId(String username) {
    final hash = username.hashCode.abs();
    final num = hash % 9000 + 1000;
    final a = String.fromCharCode(65 + hash % 26);
    final b = String.fromCharCode(65 + (hash >> 4) % 26);
    return '#$num-$a$b';
  }

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
    final riskLevel = data.riskLevel ??
        _riskLevelFromConsistencyScore(data.profileConsistencyScore);
    final handle = data.scrapedProfile?.username ??
        data.discoveredIdentifiers?.handles.firstOrNull ??
        'Unknown identity';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.riskLevelColor(riskLevel),
                          AppTheme.riskLevelBackground(riskLevel),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(
                      Icons.person_search,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RiskBadge(label: riskLevel),
                        const SizedBox(height: 12),
                        Text(
                          handle.startsWith('@') ? handle : '@$handle',
                          style: AppTheme.headline(
                            28,
                            color: AppTheme.primary,
                            weight: FontWeight.w800,
                          ),
                        ),
                        if (data.scrapedProfile?.platform != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            data.scrapedProfile!.platform!,
                            style: AppTheme.label(10, weight: FontWeight.w700),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          _buildCaseId(handle),
                          style: AppTheme.label(
                            10,
                            color: AppTheme.onSurfaceVariant,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  MetricRing(
                    score: data.profileConsistencyScore,
                    label: 'CONSISTENCY SCORE',
                    color: AppTheme.riskColor(data.profileConsistencyScore),
                    size: 108,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                data.backgroundSummary,
                style: AppTheme.body(
                  13,
                  color: AppTheme.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        if (riskLevel == 'HIGH' || riskLevel == 'CRITICAL') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.errorContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 18, color: AppTheme.error),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Discrepancy detected between claimed identity and digital footprint.',
                    style: AppTheme.body(13, color: AppTheme.error, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        _ResultBlock(
          title: 'Photo Verification',
          icon: Icons.image_search,
          child: data.photoFoundOnline
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const RiskBadge(
                      label: 'Found online',
                      color: AppTheme.error,
                      background: AppTheme.errorContainer,
                    ),
                    const SizedBox(height: 12),
                    ...data.photoSources.map(
                      (url) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          url,
                          style: AppTheme.body(
                            12,
                            color: AppTheme.primary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : const _GreenCheck(
                  'No unrelated online image matches were surfaced.',
                ),
        ),
        const SizedBox(height: 14),
        _ResultBlock(
          title: 'Username Match',
          icon: Icons.hub_outlined,
          child: data.usernamePlatforms.isEmpty
              ? Text(
                  'No strong cross-platform handle presence was found in the checked networks.',
                  style: AppTheme.body(
                    12,
                    color: AppTheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: data.usernamePlatforms
                      .map((platform) => _InfoChip(label: platform))
                      .toList(),
                ),
        ),
        if (_params?.phone != null || phones.isNotEmpty) ...[
          const SizedBox(height: 14),
          _ResultBlock(
            title: 'Phone Validation',
            icon: Icons.phonelink_setup,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    RiskBadge(
                      label: data.phoneValid ? 'Valid' : 'Invalid',
                      color:
                          data.phoneValid ? AppTheme.success : AppTheme.error,
                      background: data.phoneValid
                          ? AppTheme.successContainer
                          : AppTheme.errorContainer,
                    ),
                    if (data.phoneCountry.isNotEmpty)
                      _InfoChip(label: data.phoneCountry),
                    if (data.phoneCarrier != null)
                      _InfoChip(label: 'Carrier: ${data.phoneCarrier}'),
                  ],
                ),
                if (data.discoveredIdentifiers?.locationClaim != null) ...[
                  const SizedBox(height: 12),
                  TonalPanel(
                    radius: 20,
                    child: Text(
                      'Claimed location: ${data.discoveredIdentifiers!.locationClaim}. Current phone metadata suggests ${data.phoneCountry}.',
                      style: AppTheme.body(
                        12,
                        color: AppTheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        _ResultBlock(
          title: 'Account Authenticity',
          icon: Icons.verified_user_outlined,
          child: _AuthenticitySection(data: data),
        ),
        if (data.findings.isNotEmpty) ...[
          const SizedBox(height: 14),
          _ResultBlock(
            title: 'Evidence Cards',
            icon: Icons.flag_outlined,
            child: _FindingsSection(findings: data.findings),
          ),
        ],
        if (communityAsync != null) ...[
          const SizedBox(height: 14),
          _ResultBlock(
            title: 'Community Reports',
            icon: Icons.people_outline,
            child: communityAsync.when(
              data: (result) => _CommunityReportSection(result: result),
              loading: () => const LinearProgressIndicator(
                color: AppTheme.primaryContainer,
                minHeight: 5,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
              error: (_, __) => Text(
                'Community match unavailable.',
                style: AppTheme.body(12, color: AppTheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        GradientCtaButton(
          label: 'Flag Profile as Suspicious',
          icon: Icons.flag_outlined,
          onPressed: () => _openCommunityFlagFlow(data),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _reset,
          child: const Text('New Search'),
        ),
      ],
    );
  }

  Future<void> _openCommunityFlagFlow(BackgroundCheckResult data) async {
    final handles = data.discoveredIdentifiers?.handles ?? const <String>[];
    final phones = data.discoveredIdentifiers?.phones ?? const <String>[];
    final riskLevel = data.riskLevel ??
        _riskLevelFromConsistencyScore(data.profileConsistencyScore);
    final sessionId =
        _streamParams?.profileUrl ?? _params?.username ?? 'background-check';
    ref.read(communityLaunchIntentProvider.notifier).state = CommunityLaunchIntent(
      launchId: DateTime.now().microsecondsSinceEpoch,
      mode: CommunityLaunchMode.flag,
      platform: data.scrapedProfile?.platform ?? _selectedPlatform,
      handle: data.scrapedProfile?.username ??
          (handles.isNotEmpty ? handles.first : null),
      phone: _params?.phone ?? (phones.isNotEmpty ? phones.first : null),
      photoHash: data.photoHash,
      sourceType: 'background_check',
      sourceRiskLevel: riskLevel,
      sourceSessionId: sessionId,
    );
    ref.read(shellTabProvider.notifier).state = ShellTab.circle;
  }

  void _persistCommunityEligibility(BackgroundCheckResult data) {
    final riskLevel = data.riskLevel ??
        _riskLevelFromConsistencyScore(data.profileConsistencyScore);
    final sessionId =
        _streamParams?.profileUrl ?? _params?.username ?? 'background-check';
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
          platform: data.scrapedProfile?.platform ?? _selectedPlatform,
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

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.body,
  });

  final int index;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: AppTheme.gradientBox(radius: 999),
          child: Center(
            child: Text(
              '$index',
              style: AppTheme.headline(
                12,
                color: Colors.white,
                weight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            body,
            style: AppTheme.body(
              12,
              color: AppTheme.onSurfaceVariant,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultBlock extends StatelessWidget {
  const _ResultBlock({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTheme.headline(18, weight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.bg,
  });

  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTheme.label(10, color: color, weight: FontWeight.w800),
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

class _GreenCheck extends StatelessWidget {
  const _GreenCheck(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle_outline,
          size: 18,
          color: AppTheme.success,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: AppTheme.body(
              12,
              color: AppTheme.success,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthenticitySection extends StatelessWidget {
  const _AuthenticitySection({required this.data});

  final BackgroundCheckResult data;

  String _fmt(int n) {
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M';
    }
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}K';
    }
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final note = data.authenticityNote;
    final Color bannerColor;
    final Color textColor;
    if (note.startsWith('High confidence')) {
      bannerColor = AppTheme.successContainer;
      textColor = AppTheme.success;
    } else if (note.startsWith('Warning')) {
      bannerColor = AppTheme.errorContainer;
      textColor = AppTheme.error;
    } else {
      bannerColor = const Color(0xFFFFF3E0);
      textColor = const Color(0xFFF57F17);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatusChip(
              label: data.platformVerified ? 'Verified' : 'Not Verified',
              color: data.platformVerified
                  ? AppTheme.success
                  : const Color(0xFFF57F17),
              bg: data.platformVerified
                  ? AppTheme.successContainer
                  : const Color(0xFFFFF3E0),
            ),
            if (data.platformFollowers != null)
              _InfoChip(label: '${_fmt(data.platformFollowers!)} followers'),
            if (data.platformAccountAgeDays != null)
              _StatusChip(
                label: '${data.platformAccountAgeDays!}d old',
                color: data.platformAccountAgeDays! < 90
                    ? AppTheme.error
                    : AppTheme.primary,
                bg: data.platformAccountAgeDays! < 90
                    ? AppTheme.errorContainer
                    : AppTheme.primaryFixed,
              ),
          ],
        ),
        const SizedBox(height: 12),
        TonalPanel(
          color: bannerColor,
          child: Text(
            note,
            style: AppTheme.body(12, color: textColor, height: 1.45),
          ),
        ),
      ],
    );
  }
}

class _StreamEventRow extends StatelessWidget {
  const _StreamEventRow({required this.event});

  final BackgroundCheckEvent event;

  @override
  Widget build(BuildContext context) {
    final IconData iconData;
    final Color iconColor;
    if (event.step == CheckStep.complete) {
      iconData = Icons.check_circle;
      iconColor = AppTheme.success;
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
      iconColor = AppTheme.primary;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(iconData, size: 16, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            event.message,
            style: AppTheme.body(
              12,
              color: event.isFlag
                  ? AppTheme.onSurface
                  : AppTheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _FindingsSection extends StatelessWidget {
  const _FindingsSection({required this.findings});

  final List<DossierFinding> findings;

  static int _rank(String s) =>
      const {'critical': 0, 'high': 1, 'medium': 2, 'low': 3}[s] ?? 4;

  @override
  Widget build(BuildContext context) {
    final sorted = [...findings]
      ..sort((a, b) => _rank(a.severity).compareTo(_rank(b.severity)));
    return Column(
      children: sorted
          .map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _FindingRow(finding: f),
              ))
          .toList(),
    );
  }
}

class _FindingRow extends StatelessWidget {
  const _FindingRow({required this.finding});

  final DossierFinding finding;

  @override
  Widget build(BuildContext context) {
    final severityLabel = finding.severity.toUpperCase();
    final chipColor = AppTheme.severityColor(severityLabel);
    final chipBg = AppTheme.severityBackground(severityLabel);

    return TonalPanel(
      radius: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusChip(label: severityLabel, color: chipColor, bg: chipBg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  finding.flag,
                  style: AppTheme.headline(15, weight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  finding.evidence,
                  style: AppTheme.body(
                    12,
                    color: AppTheme.onSurfaceVariant,
                    height: 1.45,
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

class _CommunityReportSection extends StatelessWidget {
  const _CommunityReportSection({required this.result});

  final ProfileCheckResult result;

  @override
  Widget build(BuildContext context) {
    if (!result.flagged) {
      return const _GreenCheck('No community reports found for this profile.');
    }

    final status = (result.status ?? 'reported').toUpperCase();
    final color = AppTheme.severityColor(status);
    final background = AppTheme.severityBackground(status);

    return TonalPanel(
      color: background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RiskBadge(label: status, color: color, background: background),
          const SizedBox(height: 10),
          Text(
            '${result.reportCount ?? 0} report${(result.reportCount ?? 0) == 1 ? '' : 's'} on file',
            style: AppTheme.headline(18, color: color, weight: FontWeight.w800),
          ),
          if (result.firstReported != null) ...[
            const SizedBox(height: 6),
            Text(
              'First reported ${result.firstReported}',
              style: AppTheme.body(
                12,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ],
          if (result.region != null) ...[
            const SizedBox(height: 8),
            _InfoChip(label: result.region!),
          ],
          if (result.commonFlags != null && result.commonFlags!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.commonFlags!
                  .map((flag) => _InfoChip(label: flag))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
