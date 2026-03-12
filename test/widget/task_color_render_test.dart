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

List<Color> _extractWeekStripDotColors(WidgetTester tester) {
  final dots = find.byWidgetPredicate((w) {
    if (w is! Container) return false;
    final d = w.decoration;
    if (d is! BoxDecoration) return false;
    if (d.shape != BoxShape.circle) return false;
    if (d.color == null) return false;
    return true;
  });

  final colors = <Color>[];

  for (final el in dots.evaluate()) {
    final ro = el.renderObject;
    if (ro is! RenderBox) continue;
    final size = ro.size;

    final isSmall =
        size.width >= 4 && size.width <= 14 && size.height >= 4 && size.height <= 14;
    if (!isSmall) continue;

    final c = el.widget as Container;
    final d = c.decoration as BoxDecoration;
    colors.add(d.color!);
  }

  return colors;
}

Future<void> _pumpAWhile(WidgetTester tester, [int ms = 300]) async {
  await pumpFrames(tester, frames: 2);
  await tester.pump(Duration(milliseconds: ms));
  await tester.pump(Duration(milliseconds: ms));
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
    'DailyPage week strip dots use task.color override else goal color',
    (tester) async {
      final goalBox = Hive.box<Goal>(AppBoxes.goal);
      final taskBox = Hive.box<Task>(AppBoxes.task);

      final goalKey = await goalBox.add(
        Goal(
          title: 'G-Red',
          priority: 1,
          color: 0xFFFF0000,
        ),
      );

      final now = DateTime.now();
      final day = DateTime(now.year, now.month, now.day, 9);

      await taskBox.add(
        Task(
          title: 'GoalTask',
          goalId: goalKey,
          startAt: day,
          endAt: day,
          color: null,
        ),
      );

      await taskBox.add(
        Task(
          title: 'ScheduleTask',
          goalId: null,
          startAt: day,
          endAt: day,
          color: 0xFF0000FF,
        ),
      );

      final goalP = GoalProvider();
      await goalP.init(goalBox: goalBox);

      final subP = SubGoalProvider();
      await subP.init();

      final taskP = TaskProvider();
      await taskP.init(
        taskBox: taskBox,
        notification: FakeNotificationLocalService(),
      );

      final taskAdapter = ui.TaskAdapter(taskP);
      final fakeDaily = FakeDailyLogAdapter();

      final tree = GoalTreeAdapter(goalP, subP, taskP);

      final SettingsProvider settings = FakeSettingsProvider(
        inited: true,
        seenOnboarding: true,
        weekStart: WeekStart.monday,
        soundId: SoundId.none,
      );

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

      await _pumpAWhile(tester);

      final weekBtn = find.byKey(const Key('daily.view.week'));
      if (weekBtn.evaluate().isNotEmpty) {
        await tester.tap(weekBtn);
        await _pumpAWhile(tester, 200);
      }

      final colors = _extractWeekStripDotColors(tester).map((c) => c.value).toSet();

      expect(colors.contains(const Color(0xFFFF0000).value), true);
      expect(colors.contains(const Color(0xFF0000FF).value), true);

      await pumpAndSettleSafe(tester, maxFrames: 20);
    },
  );
}
