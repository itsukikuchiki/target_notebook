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

class _NotifThrows implements NotificationService {
  int ensureCalls = 0;

  @override
  bool get isReady => false;

  @override
  Future<void> init() async {}

  @override
  Future<void> ensureReady() async {
    ensureCalls++;
    throw Exception('boom');
  }

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

  testWidgets(
    'MePage: notification ensureReady throws -> shows SnackBar error',
    (tester) async {
      final user = FakeUserProvider();
      final settings = FakeSettingsProvider(
        inited: true,
        seenOnboarding: true,
        weekStart: WeekStart.monday,
        soundId: SoundId.none,
      );
      final notif = _NotifThrows();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<UserProvider>.value(value: user),
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            Provider<NotificationService>.value(value: notif),
          ],
          child: const MaterialApp(home: Scaffold(body: MePage())),
        ),
      );

      await pumpFrames(tester, frames: 2);
      await tester.pump(const Duration(milliseconds: 80));

      final tile = find.byKey(MePage.notificationTileKey);
      expect(tile, findsOneWidget);

      await tester.tap(tile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(notif.ensureCalls, 1);
      expect(find.textContaining('请求通知权限失败'), findsOneWidget);
    },
  );
}
