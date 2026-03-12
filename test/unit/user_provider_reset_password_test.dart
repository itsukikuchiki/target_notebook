// test/unit/user_provider_reset_password_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:target_notebook/providers/user_provider.dart';
import '../helpers/hive_test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserProvider.resetPassword', () {
    setUp(() async {
      await HiveTestEnv.setUp();
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() async {
      await HiveTestEnv.tearDown();
    });

    test('throws when email empty', () async {
      final u = UserProvider();
      await u.init();

      expect(
        () => u.resetPassword(email: '', newPassword: '12345678'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws when email not registered', () async {
      final u = UserProvider();
      await u.init();

      expect(
        () => u.resetPassword(email: 'a@test.com', newPassword: '12345678'),
        throwsA(isA<StateError>()),
      );
    });

    test('writes some reset marker when email registered', () async {
      final u = UserProvider();
      await u.init();

      await u.registerWithEmail(email: 'A@Test.com', password: 'pw');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_last_email'), 'a@test.com');

      final beforeKeys = prefs.getKeys();

      await u.resetPassword(email: 'A@Test.com', newPassword: '12345678');

      final afterKeys = prefs.getKeys();
      expect(afterKeys.length, greaterThanOrEqualTo(beforeKeys.length));

      // ✅ 更稳：不绑定具体 key 名，但要求出现 reset 相关记录
      final hasResetMarker = afterKeys.any((k) => k.startsWith('auth_reset_at_'));
      expect(hasResetMarker, isTrue);

      // ✅ 仍保证 last_email 不被破坏
      expect(prefs.getString('auth_last_email'), 'a@test.com');
    });
  });
}
