import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/goal.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/models/sub_goal.dart';
import 'package:target_notebook/models/daily_log.dart';
import 'package:target_notebook/pages/me_page.dart';
import 'package:target_notebook/providers/settings_provider.dart';
import 'package:target_notebook/providers/user_provider.dart';
import 'package:target_notebook/services/notification_local_service.dart';

import '../test/helpers/hive_test_env.dart';
import '../test/fakes/fake_notification_local_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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

  testWidgets('MePage delete account clears: hive + shared_prefs + avatar file + notification + returns guest', (tester) async {
    final notif = FakeNotificationLocalService();

    final settings = SettingsProvider();
    await settings.init();

    // create small temp avatar
    final tmpDir = Directory.systemTemp.createTempSync('tn_avatar_');
    final avatarFile = File('${tmpDir.path}/avatar.png');
    await avatarFile.writeAsBytes(List<int>.generate(128, (i) => i % 255));
    await settings.setAvatarPath(avatarFile.path);
    expect(settings.avatarFile != null, true);

    final user = UserProvider();
    await user.init();
    user.bindNotificationService(notif);

    // become authed so MePage has more realistic state
    await user.registerWithEmail(
      email: 'wipe@test.com',
      password: 'pw',
      displayName: 'WipeUser',
      keepLocalData: true,
    );

    // seed hive business data
    await Hive.box<Goal>(AppBoxes.goal).add(Goal(title: 'G1', priority: 1, color: 0xFF000000));
    await Hive.box<SubGoal>(AppBoxes.subGoal).add(SubGoal(goalId: 1, title: 'SG1', priority: 1));
    await Hive.box<Task>(AppBoxes.task).add(Task(title: 'T1'));
    await Hive.box<DailyLog>(AppBoxes.dailyLog).add(
      DailyLog(date: DateTime.now(), content: 'L1', minutes: 10),
    );

    expect(Hive.box<Goal>(AppBoxes.goal).isNotEmpty, true);
    expect(Hive.box<Task>(AppBoxes.task).isNotEmpty, true);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: user),
          ChangeNotifierProvider.value(value: settings),
          Provider<NotificationLocalService>.value(value: notif),
        ],
        child: const MaterialApp(home: Scaffold(body: MePage())),
      ),
    );
    await tester.pumpAndSettle();

    // tap delete tile
    await tester.tap(find.text('删除账号 & 本地数据'));
    await tester.pumpAndSettle();

    // confirm dialog
    expect(find.text('确认删除？'), findsOneWidget);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    // notification cancelAll called once (MePage calls it explicitly)
    expect(notif.cancelAllCalls, 1);

    // avatar cleared + file deleted
    expect(settings.avatarPath, isNull);
    expect(avatarFile.existsSync(), false);

    // hive cleared
    expect(Hive.box<Goal>(AppBoxes.goal).isEmpty, true);
    expect(Hive.box<SubGoal>(AppBoxes.subGoal).isEmpty, true);
    expect(Hive.box<Task>(AppBoxes.task).isEmpty, true);
    expect(Hive.box<DailyLog>(AppBoxes.dailyLog).isEmpty, true);

    // shared prefs auth cleared
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().any((k) => k.startsWith('auth_pw_hash_')), false);
    expect(prefs.containsKey('auth_last_email'), false);

    // user returned guest (UI shows Guest Mode)
    expect(find.text('Guest Mode'), findsOneWidget);

    // cleanup temp dir if still exists
    try {
      if (tmpDir.existsSync()) {
        tmpDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });
}
