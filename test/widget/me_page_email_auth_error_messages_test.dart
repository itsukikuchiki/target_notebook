import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:target_notebook/pages/me_page.dart';
import 'package:target_notebook/providers/settings_provider.dart';
import 'package:target_notebook/providers/user_provider.dart';
import 'package:target_notebook/services/notification_service_interface.dart';

import '../fakes/fake_settings_provider.dart';
import '../fakes/fake_user_provider.dart';
import '../helpers/pump_settle_safe.dart';

class _NotifNoop implements NotificationService {
  @override
  bool get isReady => true;

  @override
  Future<void> init() async {}

  @override
  Future<void> ensureReady() async {}

  @override
  Future<void> scheduleOne({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}
}

class _AuthFakeUserProvider extends FakeUserProvider {
  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
    bool keepLocalData = true,
  }) async {
    final e = email.trim().toLowerCase();
    if (e.isEmpty) throw ArgumentError('email is empty');
    if (password.isEmpty) throw ArgumentError('password is empty');

    if (e == 't@test.com') {
      if (password != 'right') {
        throw StateError('invalid password');
      }
      return;
    }

    throw StateError('email not registered');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> _pumpPage(
    WidgetTester tester, {
    required UserProvider user,
    required SettingsProvider settings,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>.value(value: user),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          Provider<NotificationService>.value(value: _NotifNoop()),
        ],
        child: const MaterialApp(home: Scaffold(body: MePage())),
      ),
    );

    await pumpFrames(tester, frames: 2);
    await tester.pump(const Duration(milliseconds: 80));
  }

  Future<void> _openEmailDialog(WidgetTester tester) async {
    await tester.tap(find.byKey(MePage.authTileKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('邮箱登录'), findsOneWidget);
    expect(find.byKey(MePage.authSubmitKey), findsOneWidget);
  }

  Future<void> _tapLogin(WidgetTester tester) async {
    await tester.tap(find.byKey(MePage.authSubmitKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
  }

  testWidgets('MePage email auth: empty email -> 请输入邮箱', (tester) async {
    final user = _AuthFakeUserProvider();
    final settings = FakeSettingsProvider(
      inited: true,
      seenOnboarding: true,
      weekStart: WeekStart.monday,
      soundId: SoundId.none,
    );

    await _pumpPage(tester, user: user, settings: settings);
    await _openEmailDialog(tester);
    await _tapLogin(tester);

    expect(find.text('请输入邮箱'), findsOneWidget);
  });

  testWidgets('MePage email auth: empty password -> 请输入密码', (tester) async {
    final user = _AuthFakeUserProvider();
    final settings = FakeSettingsProvider(
      inited: true,
      seenOnboarding: true,
      weekStart: WeekStart.monday,
      soundId: SoundId.none,
    );

    await _pumpPage(tester, user: user, settings: settings);
    await _openEmailDialog(tester);

    await tester.enterText(find.byKey(MePage.authEmailKey), 'x@test.com');
    await tester.pump();

    await _tapLogin(tester);

    expect(find.text('请输入密码'), findsOneWidget);
  });

  testWidgets('MePage email auth: not registered -> 该邮箱未注册，请先注册', (tester) async {
    final user = _AuthFakeUserProvider();
    final settings = FakeSettingsProvider(
      inited: true,
      seenOnboarding: true,
      weekStart: WeekStart.monday,
      soundId: SoundId.none,
    );

    await _pumpPage(tester, user: user, settings: settings);
    await _openEmailDialog(tester);

    await tester.enterText(find.byKey(MePage.authEmailKey), 'no@test.com');
    await tester.enterText(find.byKey(MePage.authPasswordKey), 'pw');
    await tester.pump();

    await _tapLogin(tester);

    expect(find.text('该邮箱未注册，请先注册'), findsOneWidget);
  });

  testWidgets('MePage email auth: invalid password -> 密码不正确', (tester) async {
    final user = _AuthFakeUserProvider();
    final settings = FakeSettingsProvider(
      inited: true,
      seenOnboarding: true,
      weekStart: WeekStart.monday,
      soundId: SoundId.none,
    );

    await _pumpPage(tester, user: user, settings: settings);
    await _openEmailDialog(tester);

    await tester.enterText(find.byKey(MePage.authEmailKey), 't@test.com');
    await tester.enterText(find.byKey(MePage.authPasswordKey), 'wrong');
    await tester.pump();

    await _tapLogin(tester);

    expect(find.text('密码不正确'), findsOneWidget);
  });
}
