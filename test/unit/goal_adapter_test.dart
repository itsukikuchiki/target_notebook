// test/unit/goal_adapter_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/goal.dart';
import 'package:target_notebook/models/task.dart';

import 'package:target_notebook/providers/goal_provider.dart';
import 'package:target_notebook/providers/task_provider.dart';
import 'package:target_notebook/adapters/goal_adapter.dart' as ui;

import '../helpers/hive_test_env.dart';

void main() {
  setUpAll(() async {
    await HiveTestEnv.setUp();
  });

  setUp(() async {
    await clearHiveBoxes();
  });

  tearDownAll(() async {
    await HiveTestEnv.tearDown();
  });

  test('GoalAdapter.goalsVM computes progress and sorts by priority then title',
      () async {
    final goalBox = Hive.box<Goal>(AppBoxes.goal);
    final taskBox = Hive.box<Task>(AppBoxes.task);

    final g1 = Goal(title: 'B', priority: 2, color: 0xFF111111);
    final g2 = Goal(title: 'A', priority: 1);

    final k1 = await goalBox.add(g1);
    final k2 = await goalBox.add(g2);

    await taskBox.addAll([
      Task(title: 't1', goalId: k1, done: true),
      Task(title: 't2', goalId: k1, done: false),
      Task(title: 't3', goalId: k2, done: false),
    ]);

    final goalP = GoalProvider();
    await goalP.init(goalBox: goalBox, logBox: Hive.box(AppBoxes.dailyLog));

    final taskP = TaskProvider();
    await taskP.init(taskBox: taskBox);

    final adapter = ui.GoalAdapter(goalP, taskP);

    final list = adapter.goalsVM;
    expect(list.length, 2);

    // sorted by priority asc: A (P1) first, then B (P2)
    expect(list.first.title, 'A');
    expect(list.last.title, 'B');

    final vmB = list.firstWhere((e) => e.id == k1);
    expect(vmB.tasksCount, 2);
    expect(vmB.doneCount, 1);
    expect(vmB.progress, closeTo(0.5, 1e-9));
    expect(vmB.color, 0xFF111111);
  });
}

