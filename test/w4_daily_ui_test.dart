// test/w4_daily_ui_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:target_notebook/pages/daily_page.dart';
import 'package:target_notebook/adapters/dailylog_adapter.dart';
import 'package:target_notebook/adapters/task_adapter.dart';
import 'package:target_notebook/providers/daily_log_provider.dart';
import 'package:target_notebook/providers/task_provider.dart';

/// ------- Fake DailyLogAdapter -------

class FakeDailyLogAdapter extends DailyLogAdapter {
  int quickLogCallCount = 0;
  int? lastMinutes;
  String? lastContent;

  FakeDailyLogAdapter() : super(DailyLogProvider());

  @override
  Future<int> addQuickLog({
    required DateTime date,
    required String content,
    required int minutes,
    int? taskId,
    int? goalId,
  }) async {
    quickLogCallCount++;
    lastMinutes = minutes;
    lastContent = content;
    notifyListeners();
    return quickLogCallCount;
  }

  @override
  WeeklyStatsVM weeklyStats({DateTime? now}) {
    return WeeklyStatsVM(
      {DateTime(2025, 1, 1): 2.0},
      1.0,
      '本周累计 2.0 小时',
    );
  }

  @override
  List<ReflectionVM> latestReflections({int limit = 10}) => const [];
}

/// ------- Fake TaskAdapter -------

class FakeTaskAdapter extends TaskAdapter {
  FakeTaskAdapter() : super(TaskProvider());

  List<TaskVM> _tasks = [];
  List<TaskVM> _top3 = [];

  int newTaskCallCount = 0;
  String? lastNewTitle;

  void seedTasks(List<TaskVM> tasks, {List<TaskVM>? top3}) {
    _tasks = List.of(tasks);
    _top3 = top3 ?? _tasks.take(3).toList();
    notifyListeners();
  }

  @override
  List<TaskVM> tasksForDate(DateTime day) => _tasks;

  @override
  List<TaskVM> top3ForDate(DateTime day) => _top3;

  @override
  Future<int> newTask({
    required String title,
    DateTime? date,
    int? goalId,
  }) async {
    newTaskCallCount++;
    lastNewTitle = title;

    final newId = _tasks.isEmpty
        ? 1
        : (_tasks.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1);

    final d = date ?? DateTime.now();
    final vm = TaskVM(newId, title, d, false, goalId: goalId);
    _tasks.add(vm);
    notifyListeners();
    return newId;
  }
}

void main() {
  group('W4 Daily UI', () {
    late FakeDailyLogAdapter daily;
    late FakeTaskAdapter task;

    Widget buildApp() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<DailyLogAdapter>.value(value: daily),
          ChangeNotifierProvider<TaskAdapter>.value(value: task),
        ],
        child: const MaterialApp(
          home: DailyPage(),
        ),
      );
    }

    setUp(() {
      daily = FakeDailyLogAdapter();
      task = FakeTaskAdapter();
      // 默认给一个任务，id=10，用于计时器测试
      task.seedTasks([
        TaskVM(10, '写作', DateTime(2025, 1, 1), false),
      ]);
    });

    testWidgets('周/月切换：点击两种视图按钮（week/month toggle）',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final weekBtn = find.byKey(const Key('daily.view.week'));
      final monthBtn = find.byKey(const Key('daily.view.month'));

      expect(weekBtn, findsOneWidget);
      expect(monthBtn, findsOneWidget);

      await tester.tap(monthBtn);
      await tester.pumpAndSettle();

      await tester.tap(weekBtn);
      await tester.pumpAndSettle();
    });

    testWidgets('计时器：开始→停止→保存，触发 addQuickLog', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final timer = find.byKey(const Key('daily.task.timer.10'));
      expect(timer, findsOneWidget);

      // 开始
      await tester.tap(timer);
      await tester.pump();

      // 停止 → 弹出对话框
      await tester.tap(timer);
      await tester.pumpAndSettle();

      // 点击对话框保存
      final saveBtn = find.byKey(const Key('daily.timer.save'));
      expect(saveBtn, findsOneWidget);

      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(daily.quickLogCallCount, greaterThanOrEqualTo(1));
      expect(daily.lastMinutes, isNonZero);
    });

    testWidgets('快速日志：输入内容并保存，触发 addQuickLog', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final before = daily.quickLogCallCount;

      final textField = find.byKey(const Key('daily.quicklog.text'));
      final saveBtn = find.byKey(const Key('daily.quicklog.save'));

      expect(textField, findsOneWidget);
      expect(saveBtn, findsOneWidget);

      await tester.enterText(textField, '今天写了测试代码');

      // ⭐ 关键修复：先滚动到按钮所在位置，再点
      await tester.ensureVisible(saveBtn);

      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(daily.quickLogCallCount, greaterThan(before));
      expect(daily.lastContent, contains('测试代码'));
    });

    testWidgets('KPI 区块展示 WeeklyStatsVM 信息', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final card = find.byKey(const Key('daily.kpi.card'));
      final hoursText = find.byKey(const Key('daily.kpi.hours'));
      final tipText = find.byKey(const Key('daily.kpi.tip'));

      expect(card, findsOneWidget);
      expect(hoursText, findsOneWidget);
      expect(tipText, findsOneWidget);

      expect(find.textContaining('2.0'), findsWidgets);
      expect(find.textContaining('本周累计'), findsWidgets);
    });

    testWidgets('今日三件事卡片显示 top3 任务', (tester) async {
      // 重置 top3 数据为 3 条
      task.seedTasks([
        TaskVM(1, '任务A', DateTime(2025, 1, 1), false),
        TaskVM(2, '任务B', DateTime(2025, 1, 1), false),
        TaskVM(3, '任务C', DateTime(2025, 1, 1), false),
      ]);

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final card = find.byKey(const Key('daily.top3.card'));
      expect(card, findsOneWidget);

      expect(find.byKey(const Key('daily.top3.item.1')), findsOneWidget);
      expect(find.byKey(const Key('daily.top3.item.2')), findsOneWidget);
      expect(find.byKey(const Key('daily.top3.item.3')), findsOneWidget);
    });

    testWidgets('新增任务入口：FAB → Dialog → 保存 → 调用 newTask',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final fab = find.byKey(const Key('daily.addTask.fab'));
      expect(fab, findsOneWidget);

      await tester.tap(fab);
      await tester.pumpAndSettle();

      final titleField = find.byKey(const Key('daily.addTask.title'));
      final saveBtn = find.byKey(const Key('daily.addTask.save'));

      expect(titleField, findsOneWidget);
      expect(saveBtn, findsOneWidget);

      await tester.enterText(titleField, '写作');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(task.newTaskCallCount, greaterThanOrEqualTo(1));
      expect(task.lastNewTitle, '写作');
    });
  });
}

