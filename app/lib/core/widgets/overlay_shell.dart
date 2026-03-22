import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/background_check/background_check_screen.dart';
import '../../features/chat_monitor/chat_monitor_screen.dart';
import '../../features/community/community_screen.dart';
import '../../features/video_monitor/video_monitor_screen.dart';
import '../api/api_client.dart';
import '../theme/app_theme.dart';

class OverlayShell extends ConsumerStatefulWidget {
  const OverlayShell({super.key});

  @override
  ConsumerState<OverlayShell> createState() => _OverlayShellState();
}

class _OverlayShellState extends ConsumerState<OverlayShell> {
  int _selectedIndex = 0;
  bool _backendReachable = false;
  bool _checkingBackend = true;

  static const _screens = [
    ChatMonitorScreen(),
    VideoMonitorScreen(),
    BackgroundCheckScreen(),
    CommunityScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkBackend();
  }

  Future<void> _checkBackend() async {
    final reachable = await ApiClient.instance.isBackendReachable();
    if (mounted) {
      setState(() {
        _backendReachable = reachable;
        _checkingBackend = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          _AppHeader(),
          if (!_checkingBackend && !_backendReachable)
            _BackendBanner(onRetry: _checkBackend),
          Expanded(child: _screens[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
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
  @override
  Widget build(BuildContext context) {
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'AI SHIELD',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackendBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const _BackendBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF3E0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 13, color: Color(0xFFF57F17)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Backend not running — start uvicorn first',
              style: AppTheme.label(10, color: const Color(0xFF7B4700)),
            ),
          ),
          GestureDetector(
            onTap: onRetry,
            child: Text('Retry',
                style: AppTheme.label(10, color: AppTheme.primaryContainer)),
          ),
        ],
      ),
    );
  }
}
