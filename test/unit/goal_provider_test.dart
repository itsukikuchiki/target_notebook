import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/goal.dart';
import 'package:target_notebook/models/daily_log.dart';
import 'package:target_notebook/providers/goal_provider.dart';

import '../helpers/hive_test_env.dart';
import '../helpers/hive_test_env.dart' show openTestBox;

void main() {
  setUpAll(() async {
    await HiveTestEnv.setUp();
  });

  setUp(() async {
    await clearHiveBoxes();
    // GoalProvider 会打开 dailyLogBox，但 HiveTestEnv 已 open 固定 boxes；这里确保清空即可
  });

  tearDownAll(() async {
    await HiveTestEnv.tearDown();
  });

  test('goalsSorted sorts by priority asc, then createdAt asc, then title', () async {
    final goalBox = Hive.box<Goal>(AppBoxes.goal);
    final logBox = Hive.box<DailyLog>(AppBoxes.dailyLog);

    final p = GoalProvider();
    await p.init(goalBox: goalBox, logBox: logBox);

    final g1 = Goal(title: 'B', priority: 3, createdAt: DateTime(2026, 1, 2));
    final g2 = Goal(title: 'A', priority: 1, createdAt: DateTime(2026, 1, 3));
    final g3 = Goal(title: 'C', priority: 1, createdAt: DateTime(2026, 1, 1)); // earlier createdAt wins
    final g4 = Goal(title: 'A2', priority: 1, createdAt: DateTime(2026, 1, 1)); // tie createdAt -> title

    await goalBox.addAll([g1, g2, g3, g4]);

    final titles = p.goalsSorted.map((e) => e.title).toList();

    // priority 1 first, createdAt earlier first, then title
    // createdAt 2026-01-01: A2 then C? Actually title compare: 'A2' < 'C'
    expect(titles.sublist(0, 3), ['A2', 'C', 'A']);
    expect(titles.last, 'B');
  });

  test('addGoal/updateGoal/setGoalColor/deleteGoal work and persist', () async {
    final goalBox = Hive.box<Goal>(AppBoxes.goal);
    final logBox = Hive.box<DailyLog>(AppBoxes.dailyLog);

    final p = GoalProvider();
    await p.init(goalBox: goalBox, logBox: logBox);

    final key = await p.addGoal(Goal(title: 'G', priority: 2, color: null));
    expect(p.getByKey(key)?.title, 'G');

    await p.updateGoal(
      key,
      Goal(title: 'G2', description: 'D', priority: 1, color: 0xFF112233),
    );

    final updated = p.getByKey(key)!;
    expect(updated.title, 'G2');
    expect(updated.description, 'D');
    expect(updated.priority, 1);
    expect(updated.color, 0xFF112233);

    await p.setGoalColor(key, 0xFF445566);
    expect(p.getByKey(key)!.color, 0xFF445566);

    // 持久化验证：关闭 box 再打开
    await goalBox.close();
    final reopened = await openTestBox<Goal>(AppBoxes.goal);
    final afterReopen = reopened.get(key)!;
    expect(afterReopen.title, 'G2');
    expect(afterReopen.color, 0xFF445566);

    // 删除
    await p.init(goalBox: reopened, logBox: logBox); // 重新绑定 provider 到 reopened box
    await p.deleteGoal(key);
    expect(reopened.get(key), isNull);
  });

  test('effectiveColorInt is stable for same goalKey and seed', () async {
    final goalBox = Hive.box<Goal>(AppBoxes.goal);
    final logBox = Hive.box<DailyLog>(AppBoxes.dailyLog);

    final p = GoalProvider();
    await p.init(goalBox: goalBox, logBox: logBox);

    final g = Goal(title: 'X', priority: 3, color: null);

    final c1 = p.effectiveColorInt(g, goalKey: 10, seed: 0);
    final c2 = p.effectiveColorInt(g, goalKey: 10, seed: 0);
    expect(c1, c2);

    final c3 = p.effectiveColorInt(g, goalKey: 11, seed: 0);
    expect(c1 == c3, false); // 不要求必不同，但大概率不同；这里用 seed 来确保差异
  });

  test('effectiveColorInt returns explicit color if set', () async {
    final goalBox = Hive.box<Goal>(AppBoxes.goal);
    final logBox = Hive.box<DailyLog>(AppBoxes.dailyLog);

    final p = GoalProvider();
    await p.init(goalBox: goalBox, logBox: logBox);

    final g = Goal(title: 'X', priority: 3, color: 0xFF010203);
    expect(p.effectiveColorInt(g, goalKey: 123), 0xFF010203);
  });
}

