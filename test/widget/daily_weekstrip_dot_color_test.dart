// test/widget/daily_weekstrip_dot_color_test.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';

import 'package:target_notebook/core/app_config.dart';
import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/goal.dart';
import 'package:target_notebook/models/sub_goal.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/providers/goal_provider.dart';
import 'package:target_notebook/providers/sub_goal_provider.dart';
import 'package:target_notebook/providers/task_provider.dart';
import 'package:target_notebook/providers/settings_provider.dart';
import 'package:target_notebook/adapters/task_adapter.dart' as ui;
import 'package:target_notebook/adapters/goal_tree_adapter.dart';
import 'package:target_notebook/adapters/dailylog_adapter.dart';
import 'package:target_notebook/services/holiday_service.dart';
import 'package:target_notebook/pages/daily_page.dart';

import '../helpers/hive_test_env.dart';
import '../fakes/fake_notification_local_service.dart';
import '../fakes/ui_adapters_fakes.dart';

Future<T> _realTimeout<T>(
  String name,
  Future<T> Function() run, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  debugPrint('STEP: $name');
  return await Future.any<T>([
    run(),
    Future<T>.delayed(timeout, () {
      throw TimeoutException('STEP TIMEOUT: $name after $timeout');
    }),
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await HiveTestEnv.setUp();
  });

  setUp(() async {
    await clearHiveBoxes();
    try {
      if (Hive.isBoxOpen('settings')) {
        await Hive.box('settings').clear();
      }
    } catch (_) {}
  });

  tearDownAll(() async {
    await HiveTestEnv.tearDown();
  });

  testWidgets(
    'DailyPage week strip dot colors: task.color overrides goal color, otherwise inherits goal color',
    (tester) async {
      final day = DateTime(2026, 1, 10, 9, 0);
      const goalColorInt = 0xFF3366CC;
      const overrideColorInt = 0xFFEE3344;

      late final GoalProvider goalP;
      late final SubGoalProvider subP;
      late final TaskProvider taskP;
      late final SettingsProvider settingsP;
      late final ui.TaskAdapter taskAdapter;
      late final DailyLogAdapter daily;
      late final GoalTreeAdapter tree;
      late final HolidayService holidaySvc;

      await tester.runAsync(() async {
        final goalBox = Hive.box<Goal>(AppBoxes.goal);
        final subBox = Hive.box<SubGoal>(AppBoxes.subGoal);
        final taskBox = Hive.box<Task>(AppBoxes.task);

        debugPrint('STEP: goalBox.add(Goal)');
        final goalKey = await _realTimeout<int>(
          'goalBox.add(Goal)',
          () => goalBox.add(Goal(title: 'G', priority: 1, color: goalColorInt)),
        );

        debugPrint('STEP: taskBox.add(T-inherit)');
        await _realTimeout(
          'taskBox.add(T-inherit)',
          () => taskBox.add(
            Task(
              title: 'T-inherit',
              goalId: goalKey,
              startAt: day,
              endAt: day.add(const Duration(hours: 1)),
              done: false,
              color: null,
            ),
          ),
        );

        debugPrint('STEP: taskBox.add(T-override)');
        await _realTimeout(
          'taskBox.add(T-override)',
          () => taskBox.add(
            Task(
              title: 'T-override',
              goalId: goalKey,
              startAt: day,
              endAt: day.add(const Duration(hours: 2)),
              done: false,
              color: overrideColorInt,
            ),
          ),
        );

        debugPrint('STEP: GoalProvider.init');
        goalP = GoalProvider();
        await _realTimeout('GoalProvider.init', () => goalP.init(goalBox: goalBox));

        debugPrint('STEP: SubGoalProvider.init');
        subP = SubGoalProvider();
        await _realTimeout('SubGoalProvider.init', () => subP.init(box: subBox));

        debugPrint('STEP: TaskProvider.init');
        taskP = TaskProvider();
        await _realTimeout(
          'TaskProvider.init',
          () => taskP.init(taskBox: taskBox, notification: FakeNotificationLocalService()),
        );

        debugPrint('STEP: SettingsProvider.init');
        settingsP = SettingsProvider();
        await _realTimeout('SettingsProvider.init', () => settingsP.init());

        taskAdapter = ui.TaskAdapter(taskP);
        daily = FakeDailyLogAdapter();

        holidaySvc = HolidayService(region: AppRegion.jp);
        tree = GoalTreeAdapter(goalP, subP, taskP);
      });

      addTearDown(() async {
        try {
          await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
          await tester.pump();
        } catch (_) {}

        daily.dispose();
        taskAdapter.dispose();
        taskP.dispose();
        subP.dispose();
        goalP.dispose();
        settingsP.dispose();
      });

      debugPrint('STEP: taskP.tasksForDate(day) len=${taskP.tasksForDate(day).length}');
      expect(taskP.tasksForDate(day).isNotEmpty, isTrue);

      debugPrint('STEP: pumpWidget(DailyPage initialDate=day)');
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GoalProvider>.value(value: goalP),
            ChangeNotifierProvider<SubGoalProvider>.value(value: subP),
            ChangeNotifierProvider<TaskProvider>.value(value: taskP),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsP),

            // DailyPage reads nullable -> provide both
            ListenableProvider<GoalTreeAdapter>.value(value: tree),
            ListenableProvider<GoalTreeAdapter?>.value(value: tree),
            ListenableProvider<TaskProvider>.value(value: taskP),
            ListenableProvider<TaskProvider?>.value(value: taskP),

            ChangeNotifierProvider<ui.TaskAdapter>.value(value: taskAdapter),
            ChangeNotifierProvider<DailyLogAdapter>.value(value: daily),
            Provider<HolidayService>.value(value: holidaySvc),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: DailyPage(initialDate: day),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800)); // 等 postFrame holiday refresh

      final calendar = find.byKey(const Key('daily.calendar.card'));
      expect(calendar, findsOneWidget);

      // Calendar 内找圆点（week strip dots）
      final rawDots = find.descendant(
        of: calendar,
        matching: find.byWidgetPredicate((w) {
          if (w is! Container) return false;
          final d = w.decoration;
          if (d is! BoxDecoration) return false;
          if (d.shape != BoxShape.circle) return false;
          return d.color != null;
        }),
      );
      expect(rawDots, findsWidgets, reason: 'No colored circle containers found inside calendar.');

      // ✅ 修复：不要用 6x6 过滤（Container 的 margin 会影响 getSize，实际可能是 10x6）
      final dotValues = <int>{};
      final count = rawDots.evaluate().length;

      for (var i = 0; i < count; i++) {
        final f = rawDots.at(i);

        // optional debug：确认尺寸（通常会是 10x6）
        final size = tester.getSize(f);

        final c = tester.widget<Container>(f);
        final deco = c.decoration as BoxDecoration;
        dotValues.add(deco.color!.value);

        debugPrint(
          'STEP: dot[$i] size=${size.width}x${size.height} color=${deco.color!.value.toRadixString(16)}',
        );
      }

      debugPrint('STEP: dotValues=${dotValues.map((e) => e.toRadixString(16)).toList()}');

      expect(dotValues.isNotEmpty, isTrue, reason: 'No colored dots found in week strip.');
      expect(dotValues.contains(goalColorInt), isTrue, reason: 'Expected goal color dot not found.');
      expect(dotValues.contains(overrideColorInt), isTrue, reason: 'Expected override task color dot not found.');
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
