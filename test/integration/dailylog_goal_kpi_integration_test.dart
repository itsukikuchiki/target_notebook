import 'dart:io';
import 'package:test/test.dart';
import 'package:hive/hive.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/goal.dart';
import 'package:target_notebook/models/kpi.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/providers/goal_provider.dart';
import 'package:target_notebook/providers/task_provider.dart';
import 'package:target_notebook/providers/daily_log_provider.dart';
import 'package:target_notebook/adapters/dailylog_adapter.dart';

import '../hive_test_util.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await initHiveTest();
    await Hive.openBox<Goal>(AppBoxes.goal);
    await Hive.openBox<Task>(AppBoxes.task);
    await Hive.openBox(AppBoxes.dailyLog); // dynamic box ok
  });

  tearDown(() async {
    await disposeHiveTest(dir);
  });

  test('addQuickLog 透传 goalId 并刷新 KPI（每周学习时长）', () async {
    final gp = GoalProvider();
    final tp = TaskProvider();
    final lp = DailyLogProvider();
    await gp.init();
    await tp.init();
    await lp.init();

    // 1) 新建带 KPI 的 Goal
    final g = Goal(
      title: '英语',
      kpis: [KPI(name: '每周学习时长', targetValue: 10, currentValue: 0, unit: 'hrs', period: 'weekly')],
    );
    final gKey = await gp.addGoal(g);

    // 2) 新建归属该 Goal 的任务
    final tKey = (await tp.addTask(Task(title: '背单词', goalId: gKey, startAt: DateTime(2025, 11, 3, 9)))).require;

    // 3) 通过 DailyLogAdapter 记一笔 90 分钟，且附带 taskId + goalId
    final adapter = DailyLogAdapter(lp, tp);
    final when = DateTime(2025, 11, 3, 21); // 同一天
    await adapter.addQuickLog(
      date: when,
      content: '学习单词',
      minutes: 90,
      taskId: tKey,
      goalId: gKey,
    );

    // 4) 断言 KPI 刷新到 1.5 小时
    final saved = Hive.box<Goal>(AppBoxes.goal).get(gKey)!;
    final hour = saved.kpis.first.currentValue;
    expect(hour, closeTo(1.5, 1e-9));
  });
}
