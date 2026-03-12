// test/widget/me_page_settings_and_reset_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:target_notebook/pages/me_page.dart';
import 'package:target_notebook/providers/settings_provider.dart';
import 'package:target_notebook/providers/user_provider.dart';
import 'package:target_notebook/services/notification_local_service.dart';

import '../fakes/fake_user_provider.dart';
import '../fakes/always_ready_notification_local_service.dart';
import '../helpers/hive_test_env.dart';
import '../helpers/pump_settle_safe.dart';

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
    NotificationLocalService? notification,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>.value(value: user),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          Provider<NotificationLocalService>.value(
            value: notification ?? AlwaysReadyNotificationLocalService(),
          ),
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
    'MePage: sound picker -> select Bell -> save -> SettingsProvider updated',
    (tester) async {
      final settings = SettingsProvider();
      await settings.init();

      await _pumpPage(
        tester,
        user: FakeUserProvider(),
        settings: settings,
      );

      expect(settings.soundId, SoundId.none);

      await tester.tap(find.byKey(const Key('me.settings.sound')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await pumpFrames(tester, frames: 2);

      expect(find.text('选择提示音'), findsOneWidget);

      await tester.tap(find.byKey(const Key('me.sound.option.bell')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      await tester.tap(find.byKey(const Key('me.sound.save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      await pumpFrames(tester, frames: 2);

      expect(settings.soundId, SoundId.bell);
      expect(find.text('Bell（铃）'), findsWidgets);

      await pumpAndSettleSafe(tester, maxFrames: 20);
    },
  );

  testWidgets(
    'MePage: weekStart picker -> select Sunday -> save -> SettingsProvider updated',
    (tester) async {
      final settings = SettingsProvider();
      await settings.init();

      await _pumpPage(
        tester,
        user: FakeUserProvider(),
        settings: settings,
      );

      expect(settings.weekStart, WeekStart.monday);

      await tester.tap(find.byKey(const Key('me.settings.week_start')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await pumpFrames(tester, frames: 2);

      expect(find.text('周开始日'), findsOneWidget);

      await tester.tap(find.byKey(const Key('me.week_start.option.sunday')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      await tester.tap(find.byKey(const Key('me.week_start.save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      await pumpFrames(tester, frames: 2);

      expect(settings.weekStart, WeekStart.sunday);
      expect(find.text('周日'), findsWidgets);

      await pumpAndSettleSafe(tester, maxFrames: 20);
    },
  );

  testWidgets(
    'MePage forgot password: submit -> calls UserProvider.resetPassword',
    (tester) async {
      final settings = SettingsProvider();
      await settings.init();

      final fakeUser = FakeUserProvider();

      await _pumpPage(
        tester,
        user: fakeUser,
        settings: settings,
      );

      await tester.tap(find.byKey(const Key('me.auth.open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await pumpFrames(tester, frames: 2);

      expect(find.text('忘记密码？'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_forgot_password')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await pumpFrames(tester, frames: 2);

      await tester.enterText(find.byKey(const Key('forgot.email')), 'A@Test.com');
      await tester.enterText(find.byKey(const Key('forgot.newpw')), 'newpw');
      await tester.pump();

      await tester.tap(find.byKey(const Key('forgot.submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await pumpFrames(tester, frames: 2);

      expect(fakeUser.resetPasswordCalled, true);
      expect(fakeUser.lastResetEmail, 'a@test.com');
      expect(find.textContaining('已记录重置请求'), findsOneWidget);

      await pumpAndSettleSafe(tester, maxFrames: 20);
    },
  );
}
