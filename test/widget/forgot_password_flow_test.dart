// test/widget/forgot_password_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:target_notebook/pages/me_page.dart';
import 'package:target_notebook/providers/settings_provider.dart';
import 'package:target_notebook/providers/user_provider.dart';
import 'package:target_notebook/services/notification_local_service.dart';

import '../helpers/hive_test_env.dart';
import '../helpers/pump_settle_safe.dart';
import '../fakes/fake_notification_local_service.dart';

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

  Future<void> _pumpPage(
    WidgetTester tester, {
    required UserProvider user,
    required SettingsProvider settings,
    required NotificationLocalService notif,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: user),
          ChangeNotifierProvider.value(value: settings),
          Provider<NotificationLocalService>.value(value: notif),
        ],
        child: const TickerMode(
          enabled: false,
          child: MaterialApp(home: Scaffold(body: MePage())),
        ),
      ),
    );

    await pumpFrames(tester, frames: 3);
    await tester.pump(const Duration(milliseconds: 150));
  }

  testWidgets(
    'MePage forgot password: reset -> login with new password succeeds',
    (tester) async {
      final notif = FakeNotificationLocalService();

      final settings = SettingsProvider();
      await settings.init();

      final user = UserProvider();
      await user.init();

      await user.registerWithEmail(
        email: 'fp@test.com',
        password: 'oldpw',
        displayName: 'FP',
      );

      await user.signOutToGuest();
      expect(user.isGuest, true);

      await _pumpPage(
        tester,
        user: user,
        settings: settings,
        notif: notif,
      );

      /// 打开登录 dialog
      await tester.tap(find.byKey(const Key('me.auth.open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await pumpFrames(tester, frames: 2);

      expect(find.text('邮箱登录'), findsOneWidget);

      /// 打开 reset dialog
      await tester.tap(find.byKey(const Key('btn_forgot_password')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await pumpFrames(tester, frames: 2);

      /// 填写 reset
      await tester.enterText(
        find.byKey(const Key('forgot.email')),
        'fp@test.com',
      );

      await tester.enterText(
        find.byKey(const Key('forgot.newpw')),
        'newpw',
      );

      await tester.tap(find.byKey(const Key('forgot.submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await pumpFrames(tester, frames: 2);

      /// 使用新密码登录
      await tester.enterText(
        find.byKey(const Key('me.auth.email')),
        'fp@test.com',
      );

      await tester.enterText(
        find.byKey(const Key('me.auth.password')),
        'newpw',
      );

      await tester.tap(find.byKey(const Key('me.auth.submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await pumpFrames(tester, frames: 2);

      expect(user.isAuthed, true);
      expect(find.textContaining('EMAIL · fp@test.com'), findsOneWidget);

      await pumpAndSettleSafe(tester, maxFrames: 30);
    },
  );
}
