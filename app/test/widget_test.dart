// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:fake_love_detector/core/models/backend_readiness.dart';
import 'package:fake_love_detector/core/state/backend_readiness_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fake_love_detector/main.dart';

void main() {
  testWidgets('App smoke test renders main shell', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendReadinessProvider.overrideWith(
            (ref) async => const BackendReadiness(
              status: 'ok',
              version: '0.1.0',
              readiness: 'ready',
              missingCoreEnv: [],
              missingOptionalEnv: [],
              capabilities: {
                'chat_analysis': true,
                'video_frame_analysis': true,
                'audio_analysis': true,
                'background_check': true,
                'community': true,
              },
            ),
          ),
        ],
        child: FakeLoveApp(),
      ),
    );

    // `OverlayShell` runs a backend health check in `initState`. Let any
    // pending timers complete so the test framework doesn't fail on teardown.
    await tester.pump(const Duration(seconds: 6));

    // Verify that key UI elements render (independent of backend availability).
    expect(find.text('What is Fake Love'), findsOneWidget);
    expect(find.text('ONLINE'), findsOneWidget);
    expect(find.text('Monitor'), findsOneWidget);
    expect(find.text('Visuals'), findsOneWidget);
    expect(find.text('OSINT'), findsOneWidget);
    expect(find.text('Circle'), findsOneWidget);
  });
}
