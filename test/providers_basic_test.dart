import 'dart:io';
import 'package:test/test.dart';
import 'package:hive/hive.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/core/result.dart';
import 'package:target_notebook/models/goal.dart';
import 'package:target_notebook/models/kpi.dart';
import 'package:target_notebook/models/daily_log.dart';
import 'package:target_notebook/providers/goal_provider.dart';
import 'package:target_notebook/providers/daily_log_provider.dart';

import 'hive_test_util.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await initHiveTest();
    await Hive.openBox<Goal>(AppBoxes.goal);
    await Hive.openBox<DailyLog>(AppBoxes.dailyLog);
  });

  tearDown(() async {
    await disposeHiveTest(dir);
  });

  test('daily log triggers KPI refresh weekly hours', () async {
    final gp = GoalProvider();
    final lp = DailyLogProvider();
    await gp.init();
    await lp.init();

    // 一个包含“每周学习时长”的 KPI
    final g = Goal(
      title: 'FP2',
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

    final addRes = await gp.addGoal(g);
    final goalKey = (addRes as Success<int>).value;

    // 周一写 2 小时
    final now = DateTime(2025, 10, 20, 9); // 周一
    await lp.addLog(DailyLog(date: now, content: 'study', goalId: goalKey, minutes: 120)); // 2h

    final saved = Hive.box<Goal>(AppBoxes.goal).get(goalKey)!;
    // 断言：该 KPI 已被刷新到 2.0 小时
    expect(saved.kpis.first.currentValue, closeTo(2.0, 1e-9));
  });

  test('multiple logs in the same week are accumulated into weekly KPI hours', () async {
    final gp = GoalProvider();
    final lp = DailyLogProvider();
    await gp.init();
    await lp.init();

    final g = Goal(
      title: '英语学习',
      kpis: [
        KPI(
          name: '每周学习时长',
          targetValue: 7,
          currentValue: 0,
          unit: 'hrs',
          period: 'weekly',
        ),
      ],
    );

    final addRes = await gp.addGoal(g);
    final goalKey = (addRes as Success<int>).value;

    // 同一周内三次打卡：1h + 1.5h + 2h = 4.5h
    final mon = DateTime(2025, 10, 20, 8); // 周一
    final wed = DateTime(2025, 10, 22, 20); // 周三
    final sat = DateTime(2025, 10, 25, 10); // 周六

    await lp.addLog(DailyLog(date: mon, content: 'morning reading', goalId: goalKey, minutes: 60));
    await lp.addLog(DailyLog(date: wed, content: 'listening', goalId: goalKey, minutes: 90));
    await lp.addLog(DailyLog(date: sat, content: 'speaking', goalId: goalKey, minutes: 120));

    final saved = Hive.box<Goal>(AppBoxes.goal).get(goalKey)!;
    expect(saved.kpis.first.currentValue, closeTo(4.5, 1e-9));
  });
}

