import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:target_notebook/pages/me_page.dart';
import 'package:target_notebook/providers/settings_provider.dart';
import 'package:target_notebook/providers/user_provider.dart';
import 'package:target_notebook/services/notification_local_service.dart';

import '../helpers/hive_test_env.dart';
import '../helpers/pump_settle_safe.dart';
import '../fakes/fake_user_provider.dart';

class _NotifOk extends NotificationLocalService {
  int ensureCalls = 0;

  @override
  Future<void> ensureReady() async {
    ensureCalls++;
  }

  @override
  Future<void> cancelAll() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await HiveTestEnv.setUp();
  });

  tearDownAll(() async {
    await HiveTestEnv.tearDown();
  });

  testWidgets(
    'MePage: notification ensureReady success -> shows SnackBar ok',
    (tester) async {
      final user = FakeUserProvider();
      final settings = SettingsProvider();
      await settings.init();

      final notif = _NotifOk();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<UserProvider>.value(value: user),
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            Provider<NotificationLocalService>.value(value: notif),
          ],
          child: const TickerMode(
            enabled: false,
            child: MaterialApp(home: Scaffold(body: MePage())),
          ),
        ),
      );

      await pumpFrames(tester, frames: 3);
      await tester.pump(const Duration(milliseconds: 120));

      await tester.tap(find.text('通知权限 / 后台提醒'));
      await tester.pump(); // SnackBar
      await tester.pump(const Duration(milliseconds: 50));

      expect(notif.ensureCalls, 1);
      expect(find.textContaining('已请求/确认通知权限'), findsOneWidget);

      await pumpAndSettleSafe(tester, maxFrames: 20);
    },
  );
}
