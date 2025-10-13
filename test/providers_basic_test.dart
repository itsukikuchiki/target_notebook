import 'dart:io';
import 'package:test/test.dart';
import 'package:hive/hive.dart';
import 'package:target_notebook/core/hive_init.dart';
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

    final g = Goal(title: 'FP2', kpis: [KPI(name: '每周学习时长', targetValue: 10, currentValue: 0, unit: 'hrs', period: 'weekly')]);
    final addRes = await gp.addGoal(g);
    final goalKey = addRes.require;

    final now = DateTime(2025, 10, 20, 9); // 周一
    await lp.addLog(DailyLog(date: now, content: 'study', goalId: goalKey, minutes: 120)); // 2h

    final saved = Hive.box<Goal>(AppBoxes.goal).get(goalKey)!;
    expect(saved.kpis.first.currentValue, closeTo(2.0, 1e-9));
  });
}

