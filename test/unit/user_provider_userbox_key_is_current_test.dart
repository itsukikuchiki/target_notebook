// test/unit/user_provider_userbox_key_is_current_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/app_user.dart';
import 'package:target_notebook/providers/user_provider.dart';
import '../helpers/hive_test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserProvider userBox key spec', () {
    setUp(() async {
      await HiveTestEnv.setUp();
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    tearDown(() async {
      await HiveTestEnv.tearDown();
    });

    test('userBox stores only fixed key "current" after init', () async {
      final u = UserProvider();
      await u.init();

      final box = Hive.box<AppUser>(AppBoxes.user);
      expect(box.keys.toList(), equals(['current']));
      expect(box.get('current'), isNotNull);
    });

    test('after sign-in, still uses fixed key "current"', () async {
      final u = UserProvider();
      await u.init();

      await u.registerWithEmail(email: 'a@test.com', password: 'pw');
      final box = Hive.box<AppUser>(AppBoxes.user);

      expect(box.keys.toList(), equals(['current']));
      expect(box.get('current')!.email, 'a@test.com');
      expect(box.get('current')!.isGuest, false);
    });
  });
}
