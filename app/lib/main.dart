import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'core/widgets/overlay_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(320, 480),
    minimumSize: Size(280, 400),
    center: false,
    alwaysOnTop: true,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'Fake Love Detector',
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    const ProviderScope(
      child: FakeLoveApp(),
    ),
  );
}

class FakeLoveApp extends StatelessWidget {
  const FakeLoveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fake Love Detector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE53935),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const OverlayShell(),
    );
  }
}
