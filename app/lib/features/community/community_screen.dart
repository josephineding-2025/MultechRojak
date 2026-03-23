// Owner: Member 3
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/community_flag.dart';
import 'community_provider.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  final _checkFormKey = GlobalKey<FormState>();
  final _flagFormKey = GlobalKey<FormState>();

  final _checkHandleController = TextEditingController();
  final _checkPhoneController = TextEditingController();
  final _checkPhotoHashController = TextEditingController();

  final _flagHandleController = TextEditingController();
  final _flagPhoneController = TextEditingController();
  final _flagPhotoHashController = TextEditingController();

  String _selectedPlatform = 'Telegram';
  String _selectedRegion = 'MY';
  final Set<String> _selectedFlags = <String>{};

  Map<String, String>? _checkParams;
  Map<String, dynamic>? _flagParams;

  static const _platforms = <String>[
    'Telegram',
    'WhatsApp',
    'Instagram',
    'Facebook',
    'Reddit',
    'X',
    'Dating App',
    'Other',
  ];

  static const _regions = <String>['MY', 'SG', 'ID', 'TH', 'VN', 'PH', 'Other'];

  static const _flagOptions = <String>[
    'money request',
    'fake investment',
    'identity inconsistency',
    'urgent transfer request',
    'refused video verification',
    'scripted speech',
  ];

  @override
  void dispose() {
    _checkHandleController.dispose();
    _checkPhoneController.dispose();
    _checkPhotoHashController.dispose();
    _flagHandleController.dispose();
    _flagPhoneController.dispose();
    _flagPhotoHashController.dispose();
    super.dispose();
  }

  void _submitCheck() {
    if (!_checkFormKey.currentState!.validate()) return;

    final handle = _checkHandleController.text.trim();
    final phone = _checkPhoneController.text.trim();
    final photoHash = _checkPhotoHashController.text.trim();

    setState(() {
      _checkParams = {
        if (handle.isNotEmpty) 'handle': handle,
        if (phone.isNotEmpty) 'phone': phone,
        if (photoHash.isNotEmpty) 'photo_hash': photoHash,
      };
    });
  }

  void _submitFlag() {
    if (!_flagFormKey.currentState!.validate()) return;
    if (_selectedFlags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one flag.')),
      );
      return;
    }

    final handle = _flagHandleController.text.trim();
    final phone = _flagPhoneController.text.trim();
    final photoHash = _flagPhotoHashController.text.trim();

    setState(() {
      _flagParams = {
        'platform': _selectedPlatform,
        if (handle.isNotEmpty) 'handle': handle,
        if (phone.isNotEmpty) 'phone': phone,
        if (photoHash.isNotEmpty) 'photo_hash': photoHash,
        'flags': _selectedFlags.toList(),
        'region': _selectedRegion,
      };
    });
  }

  void _resetCheck() {
    setState(() => _checkParams = null);
  }

  void _resetFlag() {
    setState(() => _flagParams = null);
  }

  @override
  Widget build(BuildContext context) {
    final checkResult = _checkParams != null ? ref.watch(profileCheckProvider(_checkParams!)) : null;
    final flagResult = _flagParams != null ? ref.watch(flagScammerProvider(_flagParams!)) : null;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TabBar(
              labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              tabs: [
                Tab(text: 'Check Profile'),
                Tab(text: 'Flag Scammer'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildCheckForm(),
                      if (checkResult != null) ...[
                        const SizedBox(height: 16),
                        checkResult.when(
                          data: _buildCheckResult,
                          loading: _buildLoading,
                          error: _buildCheckError,
                        ),
                      ],
                    ],
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildFlagForm(),
                      if (flagResult != null) ...[
                        const SizedBox(height: 16),
                        flagResult.when(
                          data: _buildFlagResult,
                          loading: _buildLoading,
                          error: _buildFlagError,
                        ),
                      ],
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

  Widget _buildCheckForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _checkFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Check whether a profile has already been reported.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _checkHandleController,
                decoration: const InputDecoration(
                  labelText: 'Handle',
                  hintText: '@john_crypto88',
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _checkPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  hintText: '+60123456789',
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 12),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _checkPhotoHashController,
                decoration: const InputDecoration(
                  labelText: 'Photo Hash',
                  hintText: 'a3f8bc92d1...',
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 12),
                validator: (_) {
                  final allEmpty = _checkHandleController.text.trim().isEmpty &&
                      _checkPhoneController.text.trim().isEmpty &&
                      _checkPhotoHashController.text.trim().isEmpty;
                  return allEmpty ? 'Provide at least one identifier.' : null;
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submitCheck,
                child: const Text('Check', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlagForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _flagFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Submit a confirmed scammer profile to the community database.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedPlatform,
                decoration: const InputDecoration(
                  labelText: 'Platform',
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 12, color: Color.fromARGB(255, 246, 197, 197)),
                items: _platforms
                    .map((platform) => DropdownMenuItem(value: platform, child: Text(platform)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedPlatform = value!),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _flagHandleController,
                decoration: const InputDecoration(
                  labelText: 'Handle',
                  hintText: '@john_crypto88',
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _flagPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  hintText: '+60123456789',
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 12),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _flagPhotoHashController,
                decoration: const InputDecoration(
                  labelText: 'Photo Hash',
                  hintText: 'a3f8bc92d1...',
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 12),
                validator: (_) {
                  final allEmpty = _flagHandleController.text.trim().isEmpty &&
                      _flagPhoneController.text.trim().isEmpty &&
                      _flagPhotoHashController.text.trim().isEmpty;
                  return allEmpty ? 'Provide at least one identifier.' : null;
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _selectedRegion,
                decoration: const InputDecoration(
                  labelText: 'Region',
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 12, color: Color.fromARGB(255, 248, 199, 199)),
                items: _regions
                    .map((region) => DropdownMenuItem(value: region, child: Text(region)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedRegion = value!),
              ),
              const SizedBox(height: 12),
              const Text(
                'Flags',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _flagOptions
                    .map(
                      (flag) => FilterChip(
                        label: Text(flag, style: const TextStyle(fontSize: 10)),
                        selected: _selectedFlags.contains(flag),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedFlags.add(flag);
                            } else {
                              _selectedFlags.remove(flag);
                            }
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submitFlag,
                child: const Text('Submit', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading...', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckError(Object error, StackTrace? _) {
    return _ErrorCard(
      title: 'Profile check failed',
      message: error.toString(),
      onRetry: _resetCheck,
    );
  }

  Widget _buildFlagError(Object error, StackTrace? _) {
    return _ErrorCard(
      title: 'Flag submission failed',
      message: error.toString(),
      onRetry: _resetFlag,
    );
  }

  Widget _buildCheckResult(ProfileCheckResult result) {
    if (!result.flagged) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _MessageCard(
            icon: Icons.check_circle_outline,
            color: Colors.green,
            title: 'No reports found',
            message: 'This profile has not been reported by the community.',
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _resetCheck,
            child: const Text('Run Another Check', style: TextStyle(fontSize: 12)),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResultCard(
          title: 'Community Match',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusBadge(status: result.status),
              const SizedBox(height: 10),
              _InfoRow(label: 'Report count', value: '${result.reportCount ?? 0}'),
              _InfoRow(label: 'First reported', value: result.firstReported ?? 'Unknown'),
              _InfoRow(label: 'Region', value: result.region ?? 'Unknown'),
              const SizedBox(height: 8),
              const Text(
                'Common flags',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              if (result.commonFlags == null || result.commonFlags!.isEmpty)
                const Text(
                  'No common flags available.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: result.commonFlags!
                      .map(
                        (flag) => Chip(
                          label: Text(flag, style: const TextStyle(fontSize: 10)),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _resetCheck,
          child: const Text('Run Another Check', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildFlagResult(FlagScammerResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MessageCard(
          icon: Icons.flag_circle,
          color: Colors.green,
          title: 'Submission recorded',
          message: 'This profile now has ${result.totalReports} total reports.',
          footer: _StatusBadge(status: result.profileStatus),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _resetFlag,
          child: const Text('Submit Another Report', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ResultCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final Widget? footer;

  const _MessageCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: color),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            if (footer != null) ...[
              const SizedBox(height: 10),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 30, color: Colors.red),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Retry', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String? status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status?.toLowerCase();
    final (label, color) = switch (normalized) {
      'confirmed' => ('Confirmed', Colors.red),
      'flagged' => ('Flagged', Colors.orange),
      'reported' => ('Reported', Colors.amber),
      _ => ('Unknown', Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
