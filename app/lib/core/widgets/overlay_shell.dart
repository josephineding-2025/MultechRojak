import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/background_check/background_check_screen.dart';
import '../../features/chat_monitor/chat_monitor_screen.dart';
import '../../features/community/community_screen.dart';
import '../../features/video_monitor/video_monitor_screen.dart';
import '../models/backend_readiness.dart';
import '../state/backend_readiness_provider.dart';
import '../state/shell_navigation.dart';
import '../theme/app_theme.dart';

class OverlayShell extends ConsumerWidget {
  const OverlayShell({super.key});

  static const _screens = [
    ChatMonitorScreen(),
    VideoMonitorScreen(),
    BackgroundCheckScreen(),
    CommunityScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(shellTabProvider);
    final selectedIndex = ShellTab.values.indexOf(selectedTab);
    final readiness = ref.watch(backendReadinessProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          _AppHeader(
            readiness: readiness,
            onRetry: () => ref.invalidate(backendReadinessProvider),
          ),
          Expanded(child: _screens[selectedIndex]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) =>
            ref.read(shellTabProvider.notifier).state = ShellTab.values[i],
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: 'Monitor',
          ),
          NavigationDestination(
            icon: Icon(Icons.videocam_outlined),
            selectedIcon: Icon(Icons.videocam),
            label: 'Visuals',
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_search),
            label: 'OSINT',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Circle',
          ),
        ],
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader({
    required this.readiness,
    required this.onRetry,
  });

  final AsyncValue<BackendReadiness> readiness;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final status = switch (readiness) {
      AsyncData(:final value) when value.isReady => _HeaderStatus(
          label: 'ONLINE',
          detail: 'All core services configured',
          color: const Color(0xFF2E7D32),
          background: const Color(0xFFDCF4E4),
          icon: Icons.security_update_good,
        ),
      AsyncData(:final value) => _HeaderStatus(
          label: 'CONFIG NEEDED',
          detail: value.missingCoreEnv.join(', '),
          color: const Color(0xFFF57F17),
          background: const Color(0xFFFFF3E0),
          icon: Icons.settings_suggest_outlined,
        ),
      AsyncError() => const _HeaderStatus(
          label: 'OFFLINE',
          detail: 'Start uvicorn main:app --reload',
          color: AppTheme.error,
          background: AppTheme.errorContainer,
          icon: Icons.cloud_off,
        ),
      _ => const _HeaderStatus(
          label: 'CHECKING',
          detail: 'Verifying backend readiness',
          color: AppTheme.primaryContainer,
          background: Color(0xFFE8EAF6),
          icon: Icons.sync,
        ),
    };

    return Container(
      height: 52,
      decoration: const BoxDecoration(gradient: AppTheme.gradient),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.security, color: Colors.white, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'What is Fake Love',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Tooltip(
            message: status.detail,
            child: GestureDetector(
              onTap: onRetry,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: status.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(status.icon, size: 12, color: status.color),
                    const SizedBox(width: 4),
                    Text(
                      status.label,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: status.color,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderStatus {
  final String label;
  final String detail;
  final Color color;
  final Color background;
  final IconData icon;

  const _HeaderStatus({
    required this.label,
    required this.detail,
    required this.color,
    required this.background,
    required this.icon,
  });
}
