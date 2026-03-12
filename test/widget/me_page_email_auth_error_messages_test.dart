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

class _NotifNoop extends NotificationLocalService {
  @override
  Future<void> ensureReady() async {}

  @override
  Future<void> cancelAll() async {}
}

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

  Future<void> _openEmailDialog(WidgetTester tester) async {
    await tester.tap(find.text('登录 / 注册（邮箱）'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await pumpFrames(tester, frames: 2);

    expect(find.text('邮箱登录'), findsOneWidget);
    expect(find.byKey(const Key('me.auth.submit')), findsOneWidget);
  }

  Future<void> _tapLogin(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('me.auth.submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('MePage email auth: empty email -> 请输入邮箱', (tester) async {
    final user = UserProvider();
    await user.init();

    final settings = SettingsProvider();
    await settings.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>.value(value: user),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          Provider<NotificationLocalService>.value(value: _NotifNoop()),
        ],
        child: const TickerMode(
          enabled: false,
          child: MaterialApp(home: Scaffold(body: MePage())),
        ),
      ),
    );

    await pumpFrames(tester, frames: 3);
    await tester.pump(const Duration(milliseconds: 150));

    await _openEmailDialog(tester);
    await _tapLogin(tester);

    expect(find.text('请输入邮箱'), findsOneWidget);

    await pumpAndSettleSafe(tester, maxFrames: 20);
  });

  testWidgets('MePage email auth: empty password -> 请输入密码', (tester) async {
    final user = UserProvider();
    await user.init();

    final settings = SettingsProvider();
    await settings.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>.value(value: user),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          Provider<NotificationLocalService>.value(value: _NotifNoop()),
        ],
        child: const TickerMode(
          enabled: false,
          child: MaterialApp(home: Scaffold(body: MePage())),
        ),
      ),
    );

    await pumpFrames(tester, frames: 3);
    await tester.pump(const Duration(milliseconds: 150));

    await _openEmailDialog(tester);

    await tester.enterText(
      find.byKey(const Key('me.auth.email')),
      'x@test.com',
    );

    await _tapLogin(tester);

    expect(find.text('请输入密码'), findsOneWidget);

    await pumpAndSettleSafe(tester, maxFrames: 20);
  });

  testWidgets('MePage email auth: not registered -> 该邮箱未注册，请先注册', (tester) async {
    final user = UserProvider();
    await user.init();

    final settings = SettingsProvider();
    await settings.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>.value(value: user),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          Provider<NotificationLocalService>.value(value: _NotifNoop()),
        ],
        child: const TickerMode(
          enabled: false,
          child: MaterialApp(home: Scaffold(body: MePage())),
        ),
      ),
    );

    await pumpFrames(tester, frames: 3);
    await tester.pump(const Duration(milliseconds: 150));

    await _openEmailDialog(tester);

    await tester.enterText(
      find.byKey(const Key('me.auth.email')),
      'no@test.com',
    );

    await tester.enterText(
      find.byKey(const Key('me.auth.password')),
      'pw',
    );

    await _tapLogin(tester);

    expect(find.text('该邮箱未注册，请先注册'), findsOneWidget);

    await pumpAndSettleSafe(tester, maxFrames: 20);
  });

  testWidgets('MePage email auth: invalid password -> 密码不正确', (tester) async {
    final user = UserProvider();
    await user.init();

    final settings = SettingsProvider();
    await settings.init();

    await user.registerWithEmail(
      email: 't@test.com',
      password: 'right',
      displayName: 'T',
    );

    await user.signOutToGuest();
    expect(user.isGuest, true);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>.value(value: user),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          Provider<NotificationLocalService>.value(value: _NotifNoop()),
        ],
        child: const TickerMode(
          enabled: false,
          child: MaterialApp(home: Scaffold(body: MePage())),
        ),
      ),
    );

    await pumpFrames(tester, frames: 3);
    await tester.pump(const Duration(milliseconds: 150));

    await _openEmailDialog(tester);

    await tester.enterText(
      find.byKey(const Key('me.auth.email')),
      't@test.com',
    );

    await tester.enterText(
      find.byKey(const Key('me.auth.password')),
      'wrong',
    );

    await _tapLogin(tester);

    expect(find.text('密码不正确'), findsOneWidget);

    await pumpAndSettleSafe(tester, maxFrames: 20);
  });
}
