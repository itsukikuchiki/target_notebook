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

  testWidgets(
    'MePage: sound picker -> select Bell -> save -> SettingsProvider updated',
    (tester) async {
      final settings = FakeSettingsProvider(
        inited: true,
        seenOnboarding: true,
        weekStart: WeekStart.monday,
        soundId: SoundId.none,
      );

      await _pumpPage(
        tester,
        user: FakeUserProvider(),
        settings: settings,
      );

      expect(settings.soundId, SoundId.none);

      await tester.tap(find.byKey(MePage.soundTileKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.text('选择提示音'), findsOneWidget);

      await tester.tap(find.byKey(const Key('me.sound.option.bell')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      await tester.tap(find.byKey(MePage.soundSaveKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(settings.soundId, SoundId.bell);
      expect(find.text('Bell（铃）'), findsWidgets);
    },
  );

  testWidgets(
    'MePage: weekStart picker -> select Sunday -> save -> SettingsProvider updated',
    (tester) async {
      final settings = FakeSettingsProvider(
        inited: true,
        seenOnboarding: true,
        weekStart: WeekStart.monday,
        soundId: SoundId.none,
      );

      await _pumpPage(
        tester,
        user: FakeUserProvider(),
        settings: settings,
      );

      expect(settings.weekStart, WeekStart.monday);

      await tester.tap(find.byKey(MePage.weekStartTileKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.text('周开始日'), findsWidgets);
      expect(find.byKey(MePage.weekStartSaveKey), findsOneWidget);

      await tester.tap(find.byKey(const Key('me.week_start.option.sunday')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      await tester.tap(find.byKey(MePage.weekStartSaveKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(settings.weekStart, WeekStart.sunday);
      expect(find.text('周日'), findsWidgets);
    },
  );

  testWidgets(
    'MePage forgot password: submit -> calls UserProvider.resetPassword',
    (tester) async {
      final settings = FakeSettingsProvider(
        inited: true,
        seenOnboarding: true,
        weekStart: WeekStart.monday,
        soundId: SoundId.none,
      );
      final fakeUser = FakeUserProvider();

      await _pumpPage(
        tester,
        user: fakeUser,
        settings: settings,
      );

      await tester.tap(find.byKey(MePage.authTileKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.text('忘记密码？'), findsOneWidget);

      await tester.tap(find.byKey(MePage.forgotButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      await tester.enterText(find.byKey(MePage.forgotEmailKey), 'A@Test.com');
      await tester.enterText(find.byKey(MePage.forgotNewPasswordKey), 'newpw');
      await tester.pump();

      await tester.tap(find.byKey(MePage.forgotSubmitKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(fakeUser.resetPasswordCalled, true);
      expect(fakeUser.lastResetEmail, 'a@test.com');
      expect(find.textContaining('已记录重置请求'), findsOneWidget);
    },
  );
}
