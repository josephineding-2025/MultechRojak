import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  static const _items = [
    _ShellItem(
      tab: ShellTab.monitor,
      label: 'Monitor',
      icon: Icons.forum_outlined,
      selectedIcon: Icons.forum,
    ),
    _ShellItem(
      tab: ShellTab.visuals,
      label: 'Visuals',
      icon: Icons.videocam_outlined,
      selectedIcon: Icons.videocam,
    ),
    _ShellItem(
      tab: ShellTab.osint,
      label: 'OSINT',
      icon: Icons.search_rounded,
      selectedIcon: Icons.search_rounded,
    ),
    _ShellItem(
      tab: ShellTab.circle,
      label: 'Circle',
      icon: Icons.group_outlined,
      selectedIcon: Icons.group,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(shellTabProvider);
    final selectedIndex = ShellTab.values.indexOf(selectedTab);
    final readiness = ref.watch(backendReadinessProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: AppTheme.editorialPageBackground(),
        child: Column(
          children: [
            _AppHeader(
              readiness: readiness,
              onRetry: () => ref.invalidate(backendReadinessProvider),
            ),
            Expanded(
              child: IndexedStack(
                index: selectedIndex,
                children: _screens,
              ),
            ),
            _BottomDock(
              selectedTab: selectedTab,
              onSelect: (tab) => ref.read(shellTabProvider.notifier).state = tab,
            ),
          ],
        ),
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
      AsyncData(:final value) when value.isReady => const _HeaderStatus(
          label: 'ONLINE',
          detail: 'All core services configured',
          color: AppTheme.success,
          background: AppTheme.successContainer,
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
          color: AppTheme.primary,
          background: AppTheme.primaryFixed,
          icon: Icons.sync,
        ),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: AppTheme.gradientBox(radius: 999),
            child: const Icon(Icons.security, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What is Fake Love',
                  style: AppTheme.headline(
                    18,
                    color: AppTheme.primary,
                    weight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'AI safety overlay for modern social trust signals',
                  style: AppTheme.body(
                    11,
                    color: AppTheme.onSurfaceVariant,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: status.detail,
            child: InkWell(
              onTap: onRetry,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: status.background,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(status.icon, size: 14, color: status.color),
                    const SizedBox(width: 6),
                    Text(
                      status.label,
                      style: AppTheme.label(
                        10,
                        color: status.color,
                        weight: FontWeight.w800,
                        letterSpacing: 1.8,
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

class _BottomDock extends StatelessWidget {
  const _BottomDock({
    required this.selectedTab,
    required this.onSelect,
  });

  final ShellTab selectedTab;
  final ValueChanged<ShellTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.55),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryContainer.withValues(alpha: 0.1),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          children: OverlayShell._items
              .map(
                (item) => Expanded(
                  child: _BottomDockItem(
                    item: item,
                    selected: selectedTab == item.tab,
                    onTap: () => onSelect(item.tab),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _BottomDockItem extends StatelessWidget {
  const _BottomDockItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _ShellItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = selected ? item.selectedIcon : item.icon;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          gradient: selected ? AppTheme.gradient : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? Colors.white : AppTheme.onSurfaceVariant,
            ),
            const SizedBox(height: 6),
            Text(
              item.label,
              style: AppTheme.label(
                10,
                color: selected ? Colors.white : AppTheme.onSurfaceVariant,
                weight: selected ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShellItem {
  const _ShellItem({
    required this.tab,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final ShellTab tab;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _HeaderStatus {
  const _HeaderStatus({
    required this.label,
    required this.detail,
    required this.color,
    required this.background,
    required this.icon,
  });

  final String label;
  final String detail;
  final Color color;
  final Color background;
  final IconData icon;
}
