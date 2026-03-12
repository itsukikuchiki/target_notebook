import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:target_notebook/providers/user_provider.dart';

import '../helpers/hive_test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test('resetPassword updates hash, old password fails, new password works', () async {
    final u = UserProvider();
    await u.init();

    await u.registerWithEmail(
      email: 'a@test.com',
      password: 'oldpw',
      displayName: 'A',
    );

    await u.signOutToGuest();
    expect(u.isGuest, true);

    // reset
    await u.resetPassword(email: 'a@test.com', newPassword: 'newpw');

    // old password should fail
    expect(
      () => u.signInWithEmail(email: 'a@test.com', password: 'oldpw'),
      throwsA(isA<StateError>()),
    );

    // new password should succeed
    await u.signInWithEmail(email: 'a@test.com', password: 'newpw');
    expect(u.isAuthed, true);
    expect(u.currentUser?.email, 'a@test.com');
  });

  test('resetPassword throws when email not registered', () async {
    final u = UserProvider();
    await u.init();

    expect(
      () => u.resetPassword(email: 'x@test.com', newPassword: 'pw'),
      throwsA(isA<StateError>()),
    );
  });
}
