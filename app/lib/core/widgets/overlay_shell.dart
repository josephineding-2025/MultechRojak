import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/chat_monitor/chat_monitor_screen.dart';
import '../../features/video_monitor/video_monitor_screen.dart';
import '../../features/background_check/background_check_screen.dart';
import '../../features/community/community_screen.dart';
import '../api/api_client.dart';

class OverlayShell extends ConsumerStatefulWidget {
  const OverlayShell({super.key});

  @override
  ConsumerState<OverlayShell> createState() => _OverlayShellState();
}

class _OverlayShellState extends ConsumerState<OverlayShell> {
  int _selectedIndex = 0;
  bool _backendReachable = false;
  bool _checkingBackend = true;

  final List<Widget> _screens = const [
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
      appBar: AppBar(
        title: const Text(
          'Fake Love Detector',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        toolbarHeight: 40,
      ),
      body: Column(
        children: [
          if (!_checkingBackend && !_backendReachable)
            Container(
              width: double.infinity,
              color: Colors.orange.shade800,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: const Text(
                'Backend not running — start uvicorn first',
                style: TextStyle(fontSize: 11, color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(child: _screens[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 56,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline, size: 20),
            selectedIcon: Icon(Icons.chat_bubble, size: 20),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.videocam_outlined, size: 20),
            selectedIcon: Icon(Icons.videocam, size: 20),
            label: 'Video',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_search_outlined, size: 20),
            selectedIcon: Icon(Icons.person_search, size: 20),
            label: 'Check',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined, size: 20),
            selectedIcon: Icon(Icons.flag, size: 20),
            label: 'Report',
          ),
        ],
      ),
    );
  }
}
