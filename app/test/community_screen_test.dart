import 'package:fake_love_detector/core/models/app_state.dart';
import 'package:fake_love_detector/features/community/community_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpCommunityScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CommunityScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('flag tab stays locked without eligible scan', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await pumpCommunityScreen(tester);

    expect(find.text('Check Profile'), findsOneWidget);
    expect(find.text('Flag Scammer'), findsOneWidget);
    expect(
      find.textContaining(
        'Complete a chat scan or background check first',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Flag Scammer'));
    await tester.pumpAndSettle();

    expect(find.text('Submit Report'), findsNothing);
    expect(find.text('CHECK PROFILE'), findsOneWidget);
  });

  testWidgets('eligible scan unlocks flag tab form', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'community_flag_eligibility': const CommunityFlagEligibility(
        sourceType: 'chat',
        sourceRiskLevel: 'LOW',
        sourceSessionId: 'session_123',
        platform: 'Instagram',
        handle: '@john_crypto88',
      ).encode(),
    });

    await pumpCommunityScreen(tester);

    await tester.tap(find.text('Flag Scammer'));
    await tester.pumpAndSettle();

    expect(find.text('Submit Report'), findsOneWidget);
    expect(find.text('@john_crypto88'), findsWidgets);
    expect(find.text('Eligible source'), findsOneWidget);
  });
}
