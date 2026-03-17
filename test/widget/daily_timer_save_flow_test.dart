import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:target_notebook/core/app_config.dart';
import 'package:target_notebook/pages/daily_page.dart';

import 'package:target_notebook/providers/settings_provider.dart';
import 'package:target_notebook/providers/task_provider.dart';
import 'package:target_notebook/providers/daily_log_provider.dart';
import 'package:target_notebook/services/holiday_service.dart';

import 'package:target_notebook/adapters/task_adapter.dart' as ui;
import 'package:target_notebook/adapters/dailylog_adapter.dart';
import 'package:target_notebook/adapters/goal_tree_adapter.dart';

import 'package:target_notebook/models/daily_log.dart' hide DailyLogAdapter;

import '../helpers/hive_test_env.dart';
import '../helpers/pump_settle_safe.dart';
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

/// 只截获 addQuickLog 参数，不碰 Hive
class FakeDailyLogProvider extends DailyLogProvider {
  int calls = 0;
  DateTime? lastDate;
  String? lastContent;
  int? lastMinutes;
  int? lastTaskId;
  int? lastGoalId;

  @override
  Future<void> init({logBox, String boxName = 'dailyLog'}) async {
    // no-op
  }

  @override
  List<DailyLog> all() => const <DailyLog>[];

  @override
  Future<int> addQuickLog({
    required DateTime date,
    required String content,
    required int minutes,
    int? taskId,
    int? goalId,
  }) async {
    calls += 1;
    lastDate = date;
    lastContent = content;
    lastMinutes = minutes;
    lastTaskId = taskId;
    lastGoalId = goalId;
    notifyListeners();
    return 0;
  }
}

/// 纯内存 TaskAdapter：让 DailyPage 能渲染任务列表，并提供 timer key
class FakeTaskAdapter extends ChangeNotifier implements ui.TaskAdapter {
  @override
  final TaskProvider src = TaskProvider();

  final List<ui.TaskVM> _tasks;

  FakeTaskAdapter(this._tasks);

  @override
  List<ui.TaskVM> tasksForDate(DateTime day) => _tasks;

  @override
  List<ui.TaskVM> top3ForDate(DateTime day) => const [];

  @override
  List<ui.TaskVM> tasksForRange(DateTime start, DateTime end) => _tasks;

  @override
  bool hasAnyTaskOn(DateTime day) => _tasks.isNotEmpty;

  @override
  Future<void> toggleTaskDone(int taskId, bool value) async {}

  @override
  Future<void> setPinnedTop3(int taskId, bool pinned) async {}

  @override
  Future<void> setTop3Order(DateTime day, List<int> orderedTaskKeys) async {}

  @override
  Future<void> deleteTask(int taskId) async {}

  @override
  Future<void> updateTask(dynamic task) async {}

  @override
  Future<int> newTask({
    required String title,
    DateTime? date,
    int? goalId,
    int? subGoalId,
    int priority = 3,
  }) async {
    throw UnimplementedError();
  }
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
    'DailyPage timer: start -> stop -> save calls addQuickLog with 25min and taskId',
    (tester) async {
      final settings = FakeSettingsProvider(
        inited: true,
        seenOnboarding: true,
        weekStart: WeekStart.monday,
        soundId: SoundId.none,
      );

      final holidaySvc = _FakeHolidayService();
      final fakeLogs = FakeDailyLogProvider();
      final dailyAdapter = DailyLogAdapter(fakeLogs);

      const taskId = 1001;
      final fakeTaskAdapter = FakeTaskAdapter([
        ui.TaskVM(
          taskId,
          'TIMER-1',
          DateTime(2026, 3, 17, 9, 0),
          false,
          priority: 3,
          startAt: DateTime(2026, 3, 17, 9, 0),
          endAt: DateTime(2026, 3, 17, 9, 30),
        ),
      ]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<HolidayService>.value(value: holidaySvc),
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            ChangeNotifierProvider<DailyLogAdapter>.value(value: dailyAdapter),
            ChangeNotifierProvider<ui.TaskAdapter>.value(value: fakeTaskAdapter),
            Provider<TaskProvider?>.value(value: null),
            Provider<GoalTreeAdapter?>.value(value: null),
          ],
          child: const MaterialApp(home: DailyPage()),
        ),
      );

      await pumpFrames(tester, frames: 5);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('TIMER-1'), findsOneWidget);

      final timerFinder = find.byKey(const Key('daily.task.timer.1001'));
      expect(timerFinder, findsOneWidget);

      // 先确保可视，再点击，避免 hitTest miss
      await tester.ensureVisible(timerFinder);
      await tester.pump();

      // 兜底滚动，适配小 viewport / CI
      final scrollable = find.byType(Scrollable);
      if (scrollable.evaluate().isNotEmpty) {
        await tester.scrollUntilVisible(
          timerFinder,
          120.0,
          scrollable: scrollable.first,
        );
        await tester.pump();
      }

      final firstButton = tester.widget<IconButton>(timerFinder);
      expect(firstButton.onPressed != null, true);

      // 第一次点击：开始计时
      await tester.tap(timerFinder);
      await tester.pump();

      // 第二次点击前再次保证可点击
      await tester.ensureVisible(timerFinder);
      await tester.pump();

      final secondButton = tester.widget<IconButton>(timerFinder);
      expect(secondButton.onPressed != null, true);

      // 第二次点击：停止计时并弹出保存对话框
      await tester.tap(timerFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.text('保存计时记录'), findsOneWidget);
      expect(find.byKey(const Key('daily.timer.save')), findsOneWidget);

      await tester.tap(find.byKey(const Key('daily.timer.save')));
      await tester.pump();

      expect(fakeLogs.calls, 1);
      expect(fakeLogs.lastMinutes, 25);
      expect(fakeLogs.lastTaskId, taskId);
      expect(fakeLogs.lastContent, contains('计时-'));

      await pumpAndSettleSafe(tester, maxFrames: 20);
    },
  );
}
