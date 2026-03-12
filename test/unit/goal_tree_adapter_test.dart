// test/unit/goal_tree_adapter_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/goal.dart';
import 'package:target_notebook/models/sub_goal.dart';
import 'package:target_notebook/models/task.dart';

import 'package:target_notebook/providers/goal_provider.dart';
import 'package:target_notebook/providers/sub_goal_provider.dart';
import 'package:target_notebook/providers/task_provider.dart';

import 'package:target_notebook/adapters/goal_tree_adapter.dart';

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

  test('GoalTreeAdapter builds nodes with subgoals + direct tasks + progress',
      () async {
    final goalBox = Hive.box<Goal>(AppBoxes.goal);
    final subBox = Hive.box<SubGoal>(AppBoxes.subGoal);
    final taskBox = Hive.box<Task>(AppBoxes.task);

    final gKey = await goalBox
        .add(Goal(title: 'G', priority: 2, color: 0xFF112233));
    final sgKey = await subBox.add(SubGoal(goalId: gKey, title: 'SG', priority: 3));

    // direct task (goal only)
    await taskBox.add(Task(title: 'DT', goalId: gKey, priority: 2, done: false));
    // subgoal tasks
    await taskBox.add(Task(
        title: 'ST done',
        goalId: gKey,
        subGoalId: sgKey,
        priority: 1,
        done: true));
    await taskBox.add(Task(
        title: 'ST todo',
        goalId: gKey,
        subGoalId: sgKey,
        priority: 3,
        done: false));

    final goalP = GoalProvider();
    final subP = SubGoalProvider();
    final taskP = TaskProvider();

    await goalP.init(goalBox: goalBox, logBox: Hive.box(AppBoxes.dailyLog));
    await subP.init(box: subBox);
    await taskP.init(taskBox: taskBox);

    final tree = GoalTreeAdapter(goalP, subP, taskP);

    expect(tree.goals.length, 1);
    final node = tree.goals.single;

    expect(node.goalKey, gKey);
    expect(node.goal.title, 'G');
    expect(node.color.value, 0xFF112233);

    // total 3 tasks, done 1 -> progress 1/3
    expect(node.totalTasks, 3);
    expect(node.doneTasks, 1);
    expect(node.progress, closeTo(1 / 3, 1e-9));

    // direct tasks should include DT only
    expect(node.directTasks.map((t) => t.title).toList(), ['DT']);

    // one subgoal with 2 tasks
    expect(node.subGoals.length, 1);
    final sg = node.subGoals.single;
    expect(sg.subGoalKey, sgKey);
    expect(sg.subGoal.title, 'SG');
    expect(sg.tasks.length, 2);

    // undone first then done
    expect(sg.tasks.first.done, false);
    expect(sg.tasks.last.done, true);
  });

  test('GoalTreeAdapter updates when providers notify (rebuild)', () async {
    final goalBox = Hive.box<Goal>(AppBoxes.goal);
    final subBox = Hive.box<SubGoal>(AppBoxes.subGoal);
    final taskBox = Hive.box<Task>(AppBoxes.task);

    final goalP = GoalProvider();
    final subP = SubGoalProvider();
    final taskP = TaskProvider();

    await goalP.init(goalBox: goalBox, logBox: Hive.box(AppBoxes.dailyLog));
    await subP.init(box: subBox);
    await taskP.init(taskBox: taskBox);

    final tree = GoalTreeAdapter(goalP, subP, taskP);

    // ❌ 不再假设初始一定为空（GoalProvider 可能会 seed 默认 goal）
    final initialCount = tree.goals.length;

    final gKey = await goalP.addGoal(Goal(title: 'G2', priority: 1));

    // 新 goal 应该出现（数量 +1）
    expect(tree.goals.length, initialCount + 1);

    final gNode = tree.goals.firstWhere((e) => e.goalKey == gKey);
    expect(gNode.goalKey, gKey);

    final sgKey = await subP.addSubGoal(SubGoal(goalId: gKey, title: 'SG2'));
    final updatedNode1 = tree.goals.firstWhere((e) => e.goalKey == gKey);
    expect(updatedNode1.subGoals.length, 1);
    expect(updatedNode1.subGoals.single.subGoalKey, sgKey);

    await taskP.addTask(
        Task(title: 'T', goalId: gKey, subGoalId: sgKey, done: true));

    final updatedNode2 = tree.goals.firstWhere((e) => e.goalKey == gKey);
    expect(updatedNode2.totalTasks, 1);
    expect(updatedNode2.doneTasks, 1);
  });
}

