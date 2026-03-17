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

  Future<void> _pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    int maxPumps = 60,
    Duration step = const Duration(milliseconds: 50),
    required String onTimeoutMessage,
  }) async {
    for (var i = 0; i < maxPumps; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.pump(step);
    }
    throw TestFailure(onTimeoutMessage);
  }

  testWidgets(
    'MePage forgot password: reset -> login with new password succeeds',
    (tester) async {
      final settings = FakeSettingsProvider(
        inited: true,
        seenOnboarding: true,
        weekStart: WeekStart.monday,
        soundId: SoundId.none,
      );

      final user = FakeUserProvider();

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
      );

      // 打开登录 dialog
      await tester.tap(find.byKey(MePage.authTileKey));
      await tester.pump();
      await _pumpUntilFound(
        tester,
        find.text('邮箱登录'),
        onTimeoutMessage: 'auth dialog not opened',
      );

      // 打开 forgot dialog
      await tester.tap(find.byKey(MePage.forgotButtonKey));
      await tester.pump();
      await _pumpUntilFound(
        tester,
        find.byKey(MePage.forgotSubmitKey),
        onTimeoutMessage: 'forgot dialog not opened',
      );

      // 填写并提交 reset
      await tester.enterText(find.byKey(MePage.forgotEmailKey), 'fp@test.com');
      await tester.enterText(find.byKey(MePage.forgotNewPasswordKey), 'newpw');
      await tester.pump();

      await tester.tap(find.byKey(MePage.forgotSubmitKey));
      await tester.pump();

      await _pumpUntilFound(
        tester,
        find.textContaining('已记录重置请求'),
        onTimeoutMessage: 'reset success snackbar not shown',
      );

      // 回到仍然打开的登录 dialog，使用新密码登录
      await tester.enterText(find.byKey(MePage.authEmailKey), 'fp@test.com');
      await tester.enterText(find.byKey(MePage.authPasswordKey), 'newpw');
      await tester.pump();

      await tester.tap(find.byKey(MePage.authSubmitKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(user.isAuthed, true);
      expect(find.textContaining('EMAIL · fp@test.com'), findsOneWidget);
    },
  );
}
