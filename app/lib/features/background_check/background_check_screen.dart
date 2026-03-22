// Owner: Member 1
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/background_check_result.dart';
import '../../core/models/community_flag.dart';
import '../community/community_provider.dart';
import 'background_check_provider.dart';

class BackgroundCheckScreen extends ConsumerStatefulWidget {
  const BackgroundCheckScreen({super.key});

  @override
  ConsumerState<BackgroundCheckScreen> createState() => _BackgroundCheckScreenState();
}

class _BackgroundCheckScreenState extends ConsumerState<BackgroundCheckScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedPlatform = 'X';
  Map<String, String>? _params;

  static const _platforms = ['X', 'GitHub', 'Instagram', 'Telegram', 'WhatsApp', 'Dating App', 'Other'];

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    if (!_formKey.currentState!.validate()) return;
    final phone = _phoneController.text.trim();
    setState(() => _params = {
          'username': _usernameController.text.trim(),
          'platform': _selectedPlatform,
          if (phone.isNotEmpty) 'phone': phone,
        });
  }

  @override
  Widget build(BuildContext context) {
    final result = _params != null ? ref.watch(backgroundCheckProvider(_params!)) : null;
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

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Background Check',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              hintText: 'e.g. john_doe123',
              isDense: true,
            ),
            style: const TextStyle(fontSize: 12),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Username is required' : null,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _selectedPlatform,
            decoration: const InputDecoration(
              labelText: 'Platform',
              isDense: true,
            ),
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            items: _platforms
                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                .toList(),
            onChanged: (v) => setState(() => _selectedPlatform = v!),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone (optional)',
              hintText: 'e.g. +60123456789',
              isDense: true,
            ),
            style: const TextStyle(fontSize: 12),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _onSubmit,
            child: const Text('Run Background Check', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 40),
        CircularProgressIndicator(),
        SizedBox(height: 12),
        Text('Checking...', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildError(Object error, StackTrace? _) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 32),
        const Icon(Icons.error_outline, color: Colors.red, size: 36),
        const SizedBox(height: 8),
        const Text('Check failed', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          error.toString(),
          style: const TextStyle(fontSize: 11, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => setState(() => _params = null),
          child: const Text('Retry', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildResult(BackgroundCheckResult data) {
    final communityAsync = data.photoHash != null
        ? ref.watch(profileCheckProvider({'photo_hash': data.photoHash!}))
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScoreCard(score: data.profileConsistencyScore),
        const SizedBox(height: 8),
        _SectionCard(
          title: 'Photo',
          icon: Icons.image_search,
          child: data.photoFoundOnline
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Chip(
                      label: Text('Found online', style: TextStyle(fontSize: 10)),
                      backgroundColor: Color(0xFFFFEBEE),
                    ),
                    const SizedBox(height: 4),
                    ...data.photoSources.map(
                      (url) => Text(
                        url,
                        style: const TextStyle(fontSize: 10, color: Colors.blue),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              : const _GreenBadge('No online matches'),
        ),
        if (_params?.containsKey('phone') == true) ...[
          const SizedBox(height: 8),
          _SectionCard(
            title: 'Phone',
            icon: Icons.phone,
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Chip(
                  label: Text(
                    data.phoneValid ? 'Valid' : 'Invalid',
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor:
                      data.phoneValid ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                ),
                if (data.phoneCountry.isNotEmpty)
                  Text(data.phoneCountry, style: const TextStyle(fontSize: 11)),
                if (data.phoneCarrier != null)
                  Text('via ${data.phoneCarrier}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        _SectionCard(
          title: 'Platforms',
          icon: Icons.devices,
          child: data.usernamePlatforms.isEmpty
              ? const Text(
                  'Not found on any checked platform',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                )
              : Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: data.usernamePlatforms
                      .map((p) => Chip(
                            label: Text(p, style: const TextStyle(fontSize: 10)),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ))
                      .toList(),
                ),
        ),
        const SizedBox(height: 8),
        _SectionCard(
          title: 'Account Authenticity',
          icon: Icons.verified_user,
          child: _AuthenticitySection(data: data),
        ),
        if (communityAsync != null) ...[
          const SizedBox(height: 8),
          _SectionCard(
            title: 'Community Reports',
            icon: Icons.people,
            child: communityAsync.when(
              data: (r) => _CommunityReportSection(result: r),
              loading: () => const SizedBox(
                height: 24,
                child: Center(child: LinearProgressIndicator()),
              ),
              error: (_, __) => const Text(
                'Community check unavailable.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        _SectionCard(
          title: 'Summary',
          icon: Icons.summarize,
          child: Text(
            data.backgroundSummary,
            style: const TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => setState(() => _params = null),
          child: const Text('Run Another Check', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}

class _AuthenticitySection extends StatelessWidget {
  final BackgroundCheckResult data;
  const _AuthenticitySection({required this.data});

  String _formatFollowers(int n) {
    if (n >= 1_000_000) return '${(n / 1_000_000).toStringAsFixed(1)}M';
    if (n >= 1_000) return '${(n / 1_000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final note = data.authenticityNote;
    final Color bannerColor;
    if (note.startsWith('High confidence')) {
      bannerColor = const Color(0xFFE8F5E9);
    } else if (note.startsWith('Warning')) {
      bannerColor = const Color(0xFFFFEBEE);
    } else {
      bannerColor = const Color(0xFFFFF8E1);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            Chip(
              label: Text(
                data.platformVerified ? 'Verified' : 'Not Verified',
                style: const TextStyle(fontSize: 10),
              ),
              backgroundColor: data.platformVerified
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFF8E1),
            ),
            if (data.platformFollowers != null)
              Chip(
                label: Text(
                  '${_formatFollowers(data.platformFollowers!)} followers',
                  style: const TextStyle(fontSize: 10),
                ),
                backgroundColor: const Color(0xFFF3E5F5),
              ),
            if (data.platformAccountAgeDays != null)
              Chip(
                label: Text(
                  '${data.platformAccountAgeDays!} days old',
                  style: const TextStyle(fontSize: 10),
                ),
                backgroundColor: data.platformAccountAgeDays! < 90
                    ? const Color(0xFFFFEBEE)
                    : const Color(0xFFE3F2FD),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: bannerColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(note, style: const TextStyle(fontSize: 11)),
        ),
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final int score;
  const _ScoreCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final Color barColor;
    final String label;
    if (score >= 70) {
      barColor = Colors.green;
      label = 'Low Risk';
    } else if (score >= 40) {
      barColor = Colors.orange;
      label = 'Medium Risk';
    } else {
      barColor = Colors.red;
      label = 'High Risk';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '$score',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: barColor,
                  ),
                ),
                const Text('/100', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: barColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(label, style: TextStyle(fontSize: 10, color: barColor)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 4),
            const Text(
              'Consistency Score (higher = more trustworthy)',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            child,
          ],
        ),
      ),
    );
  }
}

class _GreenBadge extends StatelessWidget {
  final String label;
  const _GreenBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, size: 13, color: Colors.green),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.green)),
      ],
    );
  }
}

class _CommunityReportSection extends StatelessWidget {
  final ProfileCheckResult result;
  const _CommunityReportSection({required this.result});

  @override
  Widget build(BuildContext context) {
    if (!result.flagged) {
      return const _GreenBadge('No community reports for this photo');
    }
    final statusColor = result.status == 'confirmed'
        ? Colors.red
        : result.status == 'flagged'
            ? Colors.orange
            : Colors.amber;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            Chip(
              label: Text(
                '${result.reportCount ?? 0} report${(result.reportCount ?? 0) == 1 ? "" : "s"}',
                style: const TextStyle(fontSize: 10),
              ),
              backgroundColor: statusColor.withOpacity(0.15),
            ),
            if (result.status != null)
              Chip(
                label: Text(result.status!.toUpperCase(), style: const TextStyle(fontSize: 10)),
                backgroundColor: statusColor.withOpacity(0.15),
              ),
            if (result.region != null)
              Text(result.region!, style: const TextStyle(fontSize: 11)),
          ],
        ),
        if (result.firstReported != null)
          Text('First reported: ${result.firstReported}',
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
        if (result.commonFlags != null && result.commonFlags!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: result.commonFlags!
                .map((f) => Chip(
                      label: Text(f, style: const TextStyle(fontSize: 10)),
                      backgroundColor: const Color(0xFFFFEBEE),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}
