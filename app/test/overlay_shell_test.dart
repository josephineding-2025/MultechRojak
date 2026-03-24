import 'package:fake_love_detector/core/models/backend_readiness.dart';
import 'package:fake_love_detector/core/state/backend_readiness_provider.dart';
import 'package:fake_love_detector/core/state/shell_navigation.dart';
import 'package:fake_love_detector/core/widgets/overlay_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpShell(
    WidgetTester tester, {
    required BackendReadiness readiness,
    ShellTab initialTab = ShellTab.monitor,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendReadinessProvider.overrideWith((ref) async => readiness),
          shellTabProvider.overrideWith((ref) => initialTab),
        ],
        child: const MaterialApp(home: OverlayShell()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('header shows config needed when core env vars are missing', (
    WidgetTester tester,
  ) async {
    await pumpShell(
      tester,
      readiness: const BackendReadiness(
        status: 'ok',
        version: '0.1.0',
        readiness: 'config_needed',
        missingCoreEnv: ['OPENROUTER_API_KEY', 'SUPABASE_URL'],
        missingOptionalEnv: ['OPENAI_API_KEY'],
        capabilities: {
          'chat_analysis': false,
          'video_frame_analysis': false,
          'audio_analysis': false,
          'background_check': false,
          'community': false,
        },
      ),
    );

    expect(find.text('What is Fake Love'), findsOneWidget);
    expect(find.text('CONFIG NEEDED'), findsOneWidget);
  });

  testWidgets('visuals tab renders cleanly at narrow overlay widths', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(280, 620);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpShell(
      tester,
      initialTab: ShellTab.visuals,
      readiness: const BackendReadiness(
        status: 'ok',
        version: '0.1.0',
        readiness: 'config_needed',
        missingCoreEnv: ['OPENROUTER_API_KEY'],
        missingOptionalEnv: [],
        capabilities: {
          'chat_analysis': false,
          'video_frame_analysis': false,
          'audio_analysis': false,
          'background_check': false,
          'community': false,
        },
      ),
    );

    expect(find.text('Start Monitoring'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
