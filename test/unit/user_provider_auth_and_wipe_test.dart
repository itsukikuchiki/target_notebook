// test/unit/user_provider_auth_and_wipe_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/app_user.dart';
import 'package:target_notebook/models/goal.dart';
import 'package:target_notebook/providers/user_provider.dart';

import '../helpers/hive_test_env.dart';
import '../fakes/fake_notification_local_service.dart';

void main() {
  setUpAll(() async {
    await HiveTestEnv.setUp();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await clearHiveBoxes();
  });

  tearDownAll(() async {
    await HiveTestEnv.tearDown();
  });

  test('registerWithEmail creates authed user and stores pw hash', () async {
    final u = UserProvider();
    await u.init();

    await u.registerWithEmail(email: 'a@test.com', password: 'pw', displayName: 'A');

    expect(u.isAuthed, true);
    expect(u.currentUser?.email, 'a@test.com');
    expect(u.currentUser?.displayName, 'A');

    final prefs = await SharedPreferences.getInstance();
    // existence is enough; exact key format is internal
    final keys = prefs.getKeys();
    expect(keys.any((k) => k.contains('auth_pw_hash_') && k.contains('a@test.com')), true);
  });

  test('signInWithEmail fails with wrong password', () async {
    final u = UserProvider();
    await u.init();

    await u.registerWithEmail(email: 'b@test.com', password: 'pw');

    expect(
      () => u.signInWithEmail(email: 'b@test.com', password: 'wrong'),
      throwsA(isA<StateError>()),
    );
  });

  test('wipeLocalData clears boxes, clears prefs, recreates guest, cancels all notifications', () async {
    final u = UserProvider();
    await u.init();

    // seed some business data
    await Hive.box<Goal>(AppBoxes.goal).add(Goal(title: 'g', priority: 1, color: 0xFF000000));

    final notif = FakeNotificationLocalService();
    u.bindNotificationService(notif);

    await u.registerWithEmail(email: 'c@test.com', password: 'pw');
    expect(u.isAuthed, true);

    await u.wipeLocalData();

    expect(notif.cancelAllCalls, 1);

    expect(Hive.box<Goal>(AppBoxes.goal).isEmpty, true);
    expect(Hive.box<AppUser>(AppBoxes.user).isNotEmpty, true);

    expect(u.isGuest, true);

    final prefs = await SharedPreferences.getInstance();
    // pw hashes / last email removed
    final keys = prefs.getKeys();
    expect(keys.any((k) => k.startsWith('auth_pw_hash_')), false);
    expect(keys.contains('auth_last_email'), false);
  });
}

