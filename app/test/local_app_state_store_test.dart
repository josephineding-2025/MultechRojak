import 'package:fake_love_detector/core/models/app_state.dart';
import 'package:fake_love_detector/core/storage/local_app_state_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('last community lookup round-trips through local store', () async {
    SharedPreferences.setMockInitialValues({});

    const lookup = LastCommunityLookup(
      handle: '@john_crypto88',
      phone: '+60123456789',
    );

    await LocalAppStateStore.instance.saveLastCommunityLookup(lookup);
    final loaded = await LocalAppStateStore.instance.loadLastCommunityLookup();

    expect(loaded, isNotNull);
    expect(loaded!.handle, lookup.handle);
    expect(loaded.phone, lookup.phone);
  });
}
