import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/overlay_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(390, 820),
    minimumSize: Size(360, 600),
    center: false,
    alwaysOnTop: true,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'What is Fake Love',
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
      title: 'What is Fake Love',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const OverlayShell(),
    );
  }
}
