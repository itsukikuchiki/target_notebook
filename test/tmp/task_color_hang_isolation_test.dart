import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/core/app_config.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/models/goal.dart';

import 'package:target_notebook/adapters/task_adapter.dart' as ui;
import 'package:target_notebook/adapters/goal_tree_adapter.dart';
import 'package:target_notebook/pages/daily_page.dart';

import 'package:target_notebook/providers/task_provider.dart';
import 'package:target_notebook/providers/goal_provider.dart';
import 'package:target_notebook/providers/sub_goal_provider.dart';
import 'package:target_notebook/providers/settings_provider.dart';
import 'package:target_notebook/services/holiday_service.dart';

import '../helpers/hive_test_env.dart';
import '../helpers/pump_settle_safe.dart';
import '../fakes/ui_adapters_fakes.dart';
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

Future<void> _pumpAWhile(WidgetTester tester, [int ms = 300]) async {
  await pumpFrames(tester, frames: 4);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TEST A: provider/data only', (tester) async {
    print('STEP A1: setup start (HiveTestEnv.setUp)');
    await HiveTestEnv.setUp();
    print('STEP A2: setup done');

    print('STEP A3: before clearHiveBoxes');
    await clearHiveBoxes();
    print('STEP A4: after clearHiveBoxes');

    final goalBox = Hive.box<Goal>(AppBoxes.goal);
    final taskBox = Hive.box<Task>(AppBoxes.task);

    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day, 9);

    print('STEP A5: construct goal/task data');
    final goal = Goal(title: 'G-Red', priority: 1, color: 0xFFFF0000);
    final goalTask = Task(
      title: 'GoalTask',
      goalId: null,
      startAt: day,
      endAt: day,
      color: null,
    );
    final scheduleTask = Task(
      title: 'ScheduleTask',
      goalId: null,
      startAt: day,
      endAt: day,
      color: 0xFF0000FF,
    );

    print('STEP A6: before goalBox.add');
    final goalKey = await goalBox.add(goal);
    print('STEP A7: after goalBox.add goalKey=$goalKey');

    goalTask.goalId = goalKey;

    print('STEP A8: before taskBox.add GoalTask');
    await taskBox.add(goalTask);
    print('STEP A9: after taskBox.add GoalTask');

    print('STEP A10: before taskBox.add ScheduleTask');
    await taskBox.add(scheduleTask);
    print('STEP A11: after taskBox.add ScheduleTask');

    print('STEP A12: before GoalProvider.init(goalBox: goalBox)');
    final goalP = GoalProvider();
    await goalP.init(goalBox: goalBox);
    print('STEP A13: after GoalProvider.init(goalBox: goalBox)');

    print('STEP A14: before SubGoalProvider.init()');
    final subP = SubGoalProvider();
    await subP.init();
    print('STEP A15: after SubGoalProvider.init()');

    print('STEP A16: before TaskProvider.init(taskBox: taskBox, notification: FakeNotificationLocalService())');
    final taskP = TaskProvider();
    await taskP.init(
      taskBox: taskBox,
      notification: FakeNotificationLocalService(),
    );
    print('STEP A17: after TaskProvider.init(taskBox: taskBox, notification: FakeNotificationLocalService())');

    print('STEP A18: before HiveTestEnv.tearDown');
    await HiveTestEnv.tearDown();
    print('STEP A19: after HiveTestEnv.tearDown');
  });

  testWidgets('TEST B: widget only (no goal write)', (tester) async {
    print('STEP B1: setup start (HiveTestEnv.setUp)');
    await HiveTestEnv.setUp();
    print('STEP B2: setup done');

    print('STEP B3: before clearHiveBoxes');
    await clearHiveBoxes();
    print('STEP B4: after clearHiveBoxes');

    final goalBox = Hive.box<Goal>(AppBoxes.goal);
    final taskBox = Hive.box<Task>(AppBoxes.task);

    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day, 9);

    print('STEP B5: before taskBox.add ScheduleTask only');
    await taskBox.add(
      Task(
        title: 'ScheduleTask',
        goalId: null,
        startAt: day,
        endAt: day,
        color: 0xFF0000FF,
      ),
    );
    print('STEP B6: after taskBox.add ScheduleTask only');

    print('STEP B7: before GoalProvider.init(goalBox: goalBox)');
    final goalP = GoalProvider();
    await goalP.init(goalBox: goalBox);
    print('STEP B8: after GoalProvider.init(goalBox: goalBox)');

    print('STEP B9: before SubGoalProvider.init()');
    final subP = SubGoalProvider();
    await subP.init();
    print('STEP B10: after SubGoalProvider.init()');

    print('STEP B11: before TaskProvider.init(taskBox: taskBox, notification: FakeNotificationLocalService())');
    final taskP = TaskProvider();
    await taskP.init(
      taskBox: taskBox,
      notification: FakeNotificationLocalService(),
    );
    print('STEP B12: after TaskProvider.init(taskBox: taskBox, notification: FakeNotificationLocalService())');

    final taskAdapter = ui.TaskAdapter(taskP);
    final fakeDaily = FakeDailyLogAdapter();
    final tree = GoalTreeAdapter(goalP, subP, taskP);

    final SettingsProvider settings = FakeSettingsProvider(
      inited: true,
      seenOnboarding: true,
      weekStart: WeekStart.monday,
      soundId: SoundId.none,
    );

    print('STEP B13: before tester.pumpWidget(DailyPage tree)');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HolidayService>.value(value: _FakeHolidayService()),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          Provider<GoalTreeAdapter?>.value(value: tree),
          ChangeNotifierProvider<TaskProvider?>.value(value: taskP),
          ChangeNotifierProvider<ui.TaskAdapter>.value(value: taskAdapter),
          ChangeNotifierProvider.value(value: fakeDaily),
        ],
        child: const TickerMode(
          enabled: false,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: DailyPage()),
          ),
        ),
      ),
    );
    print('STEP B14: after tester.pumpWidget(DailyPage tree)');

    print('STEP B15: before _pumpAWhile');
    await _pumpAWhile(tester);
    print('STEP B16: after _pumpAWhile');

    print('STEP B17: before tester.pump');
    await tester.pump();
    print('STEP B18: after tester.pump');

    print('STEP B19: before HiveTestEnv.tearDown');
    await HiveTestEnv.tearDown();
    print('STEP B20: after HiveTestEnv.tearDown');
  });

  testWidgets('TEST C: full reproduction with step markers', (tester) async {
    print('STEP C1: setup start (HiveTestEnv.setUp)');
    await HiveTestEnv.setUp();
    print('STEP C2: setup done');

    print('STEP C3: before clearHiveBoxes');
    await clearHiveBoxes();
    print('STEP C4: after clearHiveBoxes');

    final goalBox = Hive.box<Goal>(AppBoxes.goal);
    final taskBox = Hive.box<Task>(AppBoxes.task);

    print('STEP C5: construct goal');
    final goal = Goal(
      title: 'G-Red',
      priority: 1,
      color: 0xFFFF0000,
    );

    print('STEP C6: before goalBox.add');
    final goalKey = await goalBox.add(goal);
    print('STEP C7: after goalBox.add goalKey=$goalKey');

    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day, 9);

    print('STEP C8: before taskBox.add GoalTask');
    await taskBox.add(
      Task(
        title: 'GoalTask',
        goalId: goalKey,
        startAt: day,
        endAt: day,
        color: null,
      ),
    );
    print('STEP C9: after taskBox.add GoalTask');

    print('STEP C10: before taskBox.add ScheduleTask');
    await taskBox.add(
      Task(
        title: 'ScheduleTask',
        goalId: null,
        startAt: day,
        endAt: day,
        color: 0xFF0000FF,
      ),
    );
    print('STEP C11: after taskBox.add ScheduleTask');

    print('STEP C12: before GoalProvider.init(goalBox: goalBox)');
    final goalP = GoalProvider();
    await goalP.init(goalBox: goalBox);
    print('STEP C13: after GoalProvider.init(goalBox: goalBox)');

    print('STEP C14: before SubGoalProvider.init()');
    final subP = SubGoalProvider();
    await subP.init();
    print('STEP C15: after SubGoalProvider.init()');

    print('STEP C16: before TaskProvider.init(taskBox: taskBox, notification: FakeNotificationLocalService())');
    final taskP = TaskProvider();
    await taskP.init(
      taskBox: taskBox,
      notification: FakeNotificationLocalService(),
    );
    print('STEP C17: after TaskProvider.init(taskBox: taskBox, notification: FakeNotificationLocalService())');

    final taskAdapter = ui.TaskAdapter(taskP);
    final fakeDaily = FakeDailyLogAdapter();
    final tree = GoalTreeAdapter(goalP, subP, taskP);

    final SettingsProvider settings = FakeSettingsProvider(
      inited: true,
      seenOnboarding: true,
      weekStart: WeekStart.monday,
      soundId: SoundId.none,
    );

    print('STEP C18: before tester.pumpWidget(DailyPage tree)');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HolidayService>.value(value: _FakeHolidayService()),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          Provider<GoalTreeAdapter?>.value(value: tree),
          ChangeNotifierProvider<TaskProvider?>.value(value: taskP),
          ChangeNotifierProvider<ui.TaskAdapter>.value(value: taskAdapter),
          ChangeNotifierProvider.value(value: fakeDaily),
        ],
        child: const TickerMode(
          enabled: false,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: DailyPage()),
          ),
        ),
      ),
    );
    print('STEP C19: after tester.pumpWidget(DailyPage tree)');

    print('STEP C20: before _pumpAWhile');
    await _pumpAWhile(tester);
    print('STEP C21: after _pumpAWhile');

    print('STEP C22: before assertion placeholder sync step');
    expect(find.byType(DailyPage), findsOneWidget);
    print('STEP C23: after assertion placeholder sync step');

    print('STEP C24: before tester.pump');
    await tester.pump();
    print('STEP C25: after tester.pump');

    print('STEP C26: before HiveTestEnv.tearDown');
    await HiveTestEnv.tearDown();
    print('STEP C27: after HiveTestEnv.tearDown');
  });
}
