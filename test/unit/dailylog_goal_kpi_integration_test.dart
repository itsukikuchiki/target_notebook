// test/unit/dailylog_goal_kpi_integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/goal.dart';
import 'package:target_notebook/models/kpi.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/models/daily_log.dart';

import 'package:target_notebook/providers/goal_provider.dart';
import 'package:target_notebook/providers/task_provider.dart';
import 'package:target_notebook/providers/daily_log_provider.dart';
import 'package:target_notebook/adapters/dailylog_adapter.dart' as ui;

import 'helpers/hive_test_env.dart';

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

  test('addQuickLog 透传 goalId 并刷新 KPI（每周学习时长）', () async {
    // boxes
    final goalBox = Hive.box<Goal>(AppBoxes.goal);
    final taskBox = Hive.box<Task>(AppBoxes.task);
    final logBox = Hive.box<DailyLog>(AppBoxes.dailyLog);

    // providers
    final gp = GoalProvider();
    final tp = TaskProvider();
    final lp = DailyLogProvider();

    await gp.init(goalBox: goalBox, logBox: Hive.box(AppBoxes.dailyLog));
    await tp.init(taskBox: taskBox);

    // DailyLogProvider init：按你项目里真实签名兜底
    try {
      // ignore: avoid_dynamic_calls
      await (lp as dynamic).init(box: logBox);
    } catch (_) {
      await lp.init(logBox: Hive.box<DailyLog>(AppBoxes.dailyLog));
    }

    // 1) 新建带 KPI 的 Goal
    final g = Goal(
      title: '英语',
      kpis: [
        KPI(
          name: '每周学习时长',
          targetValue: 10,
          currentValue: 0,
          unit: 'hrs',
          period: 'weekly',
        ),
      ],
    );
    final gKey = await gp.addGoal(g);

    // 2) 新建归属该 Goal 的任务
    final res = await tp.addTask(
      Task(
        title: '背单词',
        goalId: gKey,
        startAt: DateTime(2025, 11, 3, 9),
      ),
    );

    final int tKey = _extractIntKey(res);

    // 3) 通过 DailyLogAdapter 记一笔 90 分钟（=1.5h），附带 taskId + goalId
    final adapter = ui.DailyLogAdapter(lp);
    final when = DateTime(2025, 11, 3, 21);
    await adapter.addQuickLog(
      date: when,
      content: '学习单词',
      minutes: 90,
      taskId: tKey,
      goalId: gKey,
    );

    // 4) 断言 KPI 刷新到 1.5 小时
    final saved = goalBox.get(gKey)!;
    final hour = saved.kpis.first.currentValue;
    expect(hour, closeTo(1.5, 1e-9));
  });
}

/// 兼容项目里 Result/Success 的字段命名差异：value / data / (int) 直返
int _extractIntKey(Object? res) {
  if (res == null) {
    throw StateError('Unknown Result from addTask: null');
  }
  if (res is int) return res;

  // 常见：Result 有 isSuccess + value/data
  try {
    // ignore: avoid_dynamic_calls
    final ok = (res as dynamic).isSuccess as bool?;
    if (ok == true) {
      try {
        // ignore: avoid_dynamic_calls
        final v = (res as dynamic).value;
        if (v is int) return v;
      } catch (_) {}
      try {
        // ignore: avoid_dynamic_calls
        final d = (res as dynamic).data;
        if (d is int) return d;
      } catch (_) {}
    }
  } catch (_) {}

  // 兼容 sealed Success<int>(:value) 的情况
  try {
    // ignore: avoid_dynamic_calls
    final v = (res as dynamic).value;
    if (v is int) return v;
  } catch (_) {}
  try {
    // ignore: avoid_dynamic_calls
    final d = (res as dynamic).data;
    if (d is int) return d;
  } catch (_) {}

  throw StateError('Unknown Result from addTask: $res');
}

