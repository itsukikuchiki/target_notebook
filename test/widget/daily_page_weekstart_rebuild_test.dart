import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';

import 'package:target_notebook/core/app_config.dart';
import 'package:target_notebook/core/hive_init.dart';

import 'package:target_notebook/pages/daily_page.dart';
import 'package:target_notebook/providers/settings_provider.dart';
import 'package:target_notebook/services/holiday_service.dart';

import 'package:target_notebook/adapters/dailylog_adapter.dart';
import 'package:target_notebook/adapters/task_adapter.dart' as ui;

import 'package:target_notebook/providers/daily_log_provider.dart';
import 'package:target_notebook/providers/task_provider.dart';

import 'package:target_notebook/models/task.dart' show Task;
import 'package:target_notebook/models/daily_log.dart' show DailyLog;
import 'package:target_notebook/adapters/goal_tree_adapter.dart';

import '../helpers/hive_test_env.dart';
import '../helpers/pump_settle_safe.dart';
import '../fakes/fake_notification_local_service.dart';
import '../fakes/fake_settings_provider.dart';

class _FakeHolidayService extends HolidayService {
  _FakeHolidayService() : super(region: AppRegion.jp);

  @override
  Future<void> prefetchYears(Iterable<int> years) async {}

  @override
  Future<String?> nameOf(DateTime day) async => null;

  @override
  Future<bool> isHoliday(DateTime day) async => false;

  @override
  void clearCache() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await HiveTestEnv.setUp();
  });

  setUp(() async {
    await clearHiveBoxes();
  });

  tearDownAll(() async {
    await HiveTestEnv.tearDown();
  });

  testWidgets(
    'DailyPage week strip follows SettingsProvider.weekStart (monday <-> sunday)',
    (tester) async {
      print('STEP: create settings');
      final SettingsProvider settings = FakeSettingsProvider(
        inited: true,
        seenOnboarding: true,
        weekStart: WeekStart.monday,
        soundId: SoundId.none,
      );

      print('STEP: init TaskProvider (no seeding, no Hive writes)');
      final taskP = TaskProvider();
      await taskP.init(
        taskBox: Hive.box<Task>(AppBoxes.task),
        notification: FakeNotificationLocalService(),
      );
      final taskA = ui.TaskAdapter(taskP);

      print('STEP: init DailyLogProvider with logBox');
      final logP = DailyLogProvider();
      await logP.init(logBox: Hive.box<DailyLog>(AppBoxes.dailyLog));
      final dailyA = DailyLogAdapter(logP);

      final holiday = _FakeHolidayService();

      print('STEP: pumpWidget DailyPage');
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            Provider<HolidayService>.value(value: holiday),

            ChangeNotifierProvider<TaskProvider?>.value(value: taskP),
            ChangeNotifierProvider<ui.TaskAdapter>.value(value: taskA),
            ChangeNotifierProvider<DailyLogAdapter>.value(value: dailyA),

            Provider<GoalTreeAdapter?>.value(value: null),
          ],
          child: const TickerMode(
            enabled: false,
            child: MaterialApp(home: DailyPage()),
          ),
        ),
      );

      print('STEP: initial pumps');
      await pumpFrames(tester, frames: 3);
      await tester.pump(const Duration(milliseconds: 200));

      print('STEP: expect Monday label');
      expect(find.text('一'), findsWidgets);

      print('STEP: switch weekStart -> sunday (unawaited)');
      // ignore: unawaited_futures
      settings.setWeekStart(WeekStart.sunday);

      await pumpFrames(tester, frames: 2);
      await tester.pump(const Duration(milliseconds: 200));

      print('STEP: expect Sunday label');
      expect(find.text('日'), findsWidgets);

      final days =
          dailyVisibleDaysForWeekStrip(DateTime.now(), WeekStart.sunday);
      expect(days.first.weekday, DateTime.sunday);

      await pumpAndSettleSafe(tester, maxFrames: 20);
      print('STEP: done');
    },
  );
}
