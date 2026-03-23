import 'package:fake_love_detector/core/models/backend_readiness.dart';
import 'package:fake_love_detector/core/state/backend_readiness_provider.dart';
import 'package:fake_love_detector/features/video_monitor/video_monitor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('video monitor shows readiness message when backend is offline', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendReadinessProvider.overrideWith(
            (ref) async => const BackendReadiness(
              status: 'offline',
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
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: VideoMonitorScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start Monitoring'), findsOneWidget);
    expect(
      find.text('Start the backend first to monitor video calls.'),
      findsOneWidget,
    );
  });
}
