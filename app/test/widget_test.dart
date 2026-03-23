// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fake_love_detector/main.dart';

void main() {
  testWidgets('App smoke test renders main shell', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FakeLoveApp());

    // `OverlayShell` runs a backend health check in `initState`. Let any
    // pending timers complete so the test framework doesn't fail on teardown.
    await tester.pump(const Duration(seconds: 6));

    // Verify that key UI elements render (independent of backend availability).
    expect(find.text('Fake Love Detector'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
    expect(find.text('Check'), findsOneWidget);
    expect(find.text('Report'), findsOneWidget);
  });
}
