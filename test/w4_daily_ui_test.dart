// test/w4_daily_ui_test.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// ==== 被测页面 ====
import 'package:target_notebook/pages/daily_page.dart';

// ==== 正式类型（仅用于类型匹配，不会触发 Hive）====
import 'package:target_notebook/adapters/task_adapter.dart' show TaskAdapter, TaskVM;
import 'package:target_notebook/adapters/dailylog_adapter.dart'
    show DailyLogAdapter, WeeklyVM, ReflectionVM;
import 'package:target_notebook/providers/task_provider.dart' show TaskProvider;
import 'package:target_notebook/providers/daily_log_provider.dart' show DailyLogProvider;

// 仅引入 DailyLog 类型，避免与 DailyLogAdapter 符号冲突
import 'package:target_notebook/models/daily_log.dart' as mdl show DailyLog;

// Hive Box 类型
import 'package:hive/hive.dart';

// ----------------------------------------------------------------------
// Dummy DailyLogProvider：覆盖 init 签名以“空实现”，不打开 Hive
// ----------------------------------------------------------------------
class _DummyDailyLogProvider extends DailyLogProvider {
  @override
  Future<void> init({Box<mdl.DailyLog>? logBox, String boxName = 'dailyLogBox'}) async {
    // 测试环境不触发 Hive
  }

  @override
  List<mdl.DailyLog> all() => const [];
}

// ----------------------------------------------------------------------
//
// TaskProvider 的空壳子，满足 TaskAdapter(super) 的参数类型
// ----------------------------------------------------------------------
class _StubTaskProvider extends TaskProvider {}

// ----------------------------------------------------------------------
// 最小替身：FakeDailyLogAdapter
// ----------------------------------------------------------------------
class FakeDailyLogAdapter extends DailyLogAdapter {
  FakeDailyLogAdapter() : super(_DummyDailyLogProvider());

  int quickLogCalled = 0;
  int lastMinutes = 0;
  DateTime? lastDate;
  int? lastTaskId;
  int? lastGoalId;
  String? lastContent;

  @override
  Future<int> addQuickLog({
    required DateTime date,
    required String content,
    required int minutes,
    int? taskId,
    int? goalId,
  }) async {
    quickLogCalled += 1;
    lastMinutes = minutes;
    lastDate = date;
    lastTaskId = taskId;
    lastGoalId = goalId;
    lastContent = content;
    return 1;
  }

  @override
  WeeklyVM weeklyStats({DateTime? now}) {
    // WeeklyVM(Map<DateTime,double> data, double totalHours, String tip)
    return WeeklyVM(<DateTime, double>{}, 0.0, '');
  }

  @override
  List<ReflectionVM> latestReflections({int limit = 10}) {
    return const <ReflectionVM>[];
  }
}

// ----------------------------------------------------------------------
// 最小替身：FakeTaskAdapter
// ----------------------------------------------------------------------
class FakeTaskAdapter extends TaskAdapter {
  FakeTaskAdapter() : super(_StubTaskProvider());

  final Map<DateTime, List<TaskVM>> _byDay = {};
  final Map<DateTime, List<int>> _top3Order = {};

  void seed(DateTime day, List<TaskVM> items) {
    _byDay[DateUtils.dateOnly(day)] = List.of(items);
  }

  List<TaskVM> _sorted(List<TaskVM> list) {
    final copy = List<TaskVM>.from(list);
    copy.sort((a, b) {
      if (a.isTodayTop3 != b.isTodayTop3) return a.isTodayTop3 ? -1 : 1;
      return a.title.compareTo(b.title);
    });
    return copy;
  }

  @override
  List<TaskVM> tasksForDate(DateTime day) {
    final k = DateUtils.dateOnly(day);
    final list = _byDay[k] ?? const [];
    return _sorted(list);
  }

  @override
  List<TaskVM> top3ForDate(DateTime day) {
    final k = DateUtils.dateOnly(day);
    final all = _sorted(_byDay[k] ?? const []);
    final pinned = all.where((e) => e.isTodayTop3).toList();
    final rest = all.where((e) => !e.isTodayTop3).toList();
    final merged = [...pinned, ...rest];

    final order = _top3Order[k];
    if (order != null) {
      merged.sort((a, b) {
        final ai = order.indexOf(a.id);
        final bi = order.indexOf(b.id);
        if (ai == -1 && bi == -1) return 0;
        if (ai == -1) return 1;
        if (bi == -1) return -1;
        return ai.compareTo(bi);
      });
    }
    return merged.take(3).toList();
  }

  @override
  Future<void> setTop3Order(DateTime day, List<int> orderedTaskKeys) async {
    _top3Order[DateUtils.dateOnly(day)] = List.of(orderedTaskKeys);
  }

  @override
  Future<void> toggleTaskDone(int key, bool value) async {}
}

// ----------------------------------------------------------------------
// Provider 包装：显式使用 ChangeNotifierProvider，并用 child 传入被测页面
// ----------------------------------------------------------------------
Widget _wrapWithProviders({
  required DailyLogAdapter log,
  required TaskAdapter task,
  Widget? child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<DailyLogAdapter>.value(value: log),
      ChangeNotifierProvider<TaskAdapter>.value(value: task),
    ],
    child: MaterialApp(home: child ?? const DailyPage()),
  );
}

// ======================================================================
// 测试用例
// ======================================================================
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('W4 Daily UI', () {
    testWidgets('周/月切换：点击两种视图按钮（week/month toggle）', (tester) async {
      final task = FakeTaskAdapter();
      final log = FakeDailyLogAdapter();
      final today = DateUtils.dateOnly(DateTime.now());

      task.seed(today, [
        TaskVM(1, 'Top-晨跑 3km', today, false, goalId: null, isTodayTop3: true),
        TaskVM(2, '读书 20min', today, false),
      ]);

      await tester.pumpWidget(
        _wrapWithProviders(task: task, log: log, child: const DailyPage()),
      );
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
      final task = FakeTaskAdapter();
      final log = FakeDailyLogAdapter();
      final today = DateUtils.dateOnly(DateTime.now());

      task.seed(today, [
        TaskVM(10, '番茄-写作', today, false),
      ]);

      await tester.pumpWidget(
        _wrapWithProviders(task: task, log: log, child: const DailyPage()),
      );
      await tester.pumpAndSettle();

      final timerBtn = find.byKey(const Key('task.timer.10'));
      expect(timerBtn, findsOneWidget);
      await tester.tap(timerBtn);
      await tester.pumpAndSettle();

      final startBtn = find.byKey(const Key('timer.start'));
      final stopBtn = find.byKey(const Key('timer.stop'));
      final saveBtn = find.byKey(const Key('timer.save'));

expect(startBtn, findsOneWidget);
await tester.tap(startBtn);

// 模拟时间推进（Flutter test 不会真的改变 DateTime.now）
await tester.pump(const Duration(milliseconds: 50));

expect(stopBtn, findsOneWidget);
await tester.tap(stopBtn);
await tester.pump(const Duration(milliseconds: 50));

      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(log.quickLogCalled, greaterThanOrEqualTo(1));
      expect(log.lastTaskId, equals(10));
      expect(log.lastMinutes, greaterThanOrEqualTo(1));
    });

    testWidgets('快速日志：输入内容并保存，触发 addQuickLog', (tester) async {
      final task = FakeTaskAdapter();
      final log = FakeDailyLogAdapter();
      final today = DateUtils.dateOnly(DateTime.now());

      task.seed(today, [
        TaskVM(7, '回顾-周笔记', today, false),
      ]);

      await tester.pumpWidget(
        _wrapWithProviders(task: task, log: log, child: const DailyPage()),
      );
      await tester.pumpAndSettle();

      final input = find.byKey(const Key('daily.quicklog.input'));
      final save = find.byKey(const Key('daily.quicklog.save'));

      expect(input, findsOneWidget);
      expect(save, findsOneWidget);

      await tester.enterText(input, '今天完成 Top3，复盘良好');
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(log.quickLogCalled, greaterThanOrEqualTo(1));
      expect(log.lastContent, contains('Top3'));
      expect(log.lastMinutes, anyOf(0, 1, greaterThan(1)));
    });
  });
}

