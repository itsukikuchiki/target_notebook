import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_models.dart';
import '../fakes/fake_providers.dart';

class TestGoalNode {
  final int goalKey;
  final FakeGoal goal;
  final Color color;
  final int totalTasks;
  final int doneTasks;
  double get progress => totalTasks == 0 ? 0 : doneTasks / totalTasks;
  TestGoalNode({
    required this.goalKey,
    required this.goal,
    required this.color,
    required this.totalTasks,
    required this.doneTasks,
  });
}

/// 只用于测试：复刻你 GoalTreeAdapter 的核心聚合逻辑
class TestGoalTreeAdapter extends ChangeNotifier {
  final FakeGoalProvider goalP;
  final FakeSubGoalProvider subGoalP;
  final FakeTaskProvider taskP;

  TestGoalTreeAdapter(this.goalP, this.subGoalP, this.taskP) {
    goalP.addListener(_rebuild);
    subGoalP.addListener(_rebuild);
    taskP.addListener(_rebuild);
    _rebuild();
  }

  List<TestGoalNode> _goals = [];
  List<TestGoalNode> get goals => _goals;

  static int taskSort(FakeTask a, FakeTask b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    final p = a.priority.compareTo(b.priority);
    if (p != 0) return p;
    final da = a.startAt ?? a.deadline ?? DateTime(2100);
    final db = b.startAt ?? b.deadline ?? DateTime(2100);
    return da.compareTo(db);
  }

  void _rebuild() {
    final sortedGoals = goalP.goalsSorted;
    final result = <TestGoalNode>[];

    for (final g in sortedGoals) {
      final goalColorInt = goalP.effectiveColorInt(g, goalKey: g.key);
      final goalColor = Color(goalColorInt);

      final subGoals = subGoalP.subGoalsByGoal(g.key);
      final allTasks = taskP.tasksByGoal(g.key);

      int total = 0;
      int done = 0;

      // subgoals
      for (final sg in subGoals) {
        final sgTasks = taskP.tasksBySubGoal(sg.key)..sort(taskSort);
        total += sgTasks.length;
        done += sgTasks.where((t) => t.done).length;
      }

      // direct
      final direct = allTasks.where((t) => t.subGoalId == null).toList()..sort(taskSort);
      total += direct.length;
      done += direct.where((t) => t.done).length;

      result.add(
        TestGoalNode(
          goalKey: g.key,
          goal: g,
          color: goalColor,
          totalTasks: total,
          doneTasks: done,
        ),
      );
    }

    _goals = result;
    notifyListeners();
  }
}

void main() {
  test('GoalTreeAdapter aggregates total/done/progress correctly', () {
    final goalP = FakeGoalProvider();
    final subP = FakeSubGoalProvider();
    final taskP = FakeTaskProvider();

    goalP.seedGoals([
      FakeGoal(key: 1, title: 'A', priority: 2, color: 0xFF00FF00),
    ]);
    subP.seedSubGoals([
      FakeSubGoal(key: 11, goalId: 1, title: 'SG1'),
    ]);
    taskP.seedTasks([
      // subgoal tasks
      FakeTask(key: 101, title: 't1', goalId: 1, subGoalId: 11, done: true, priority: 3),
      FakeTask(key: 102, title: 't2', goalId: 1, subGoalId: 11, done: false, priority: 1),
      // direct tasks
      FakeTask(key: 201, title: 'd1', goalId: 1, subGoalId: null, done: false, priority: 2),
    ]);

    final tree = TestGoalTreeAdapter(goalP, subP, taskP);
    expect(tree.goals.length, 1);
    expect(tree.goals.first.totalTasks, 3);
    expect(tree.goals.first.doneTasks, 1);
    expect(tree.goals.first.progress, closeTo(1 / 3, 1e-9));
  });

  test('Task sort: undone first, then priority, then date', () {
    final a = FakeTask(key: 1, title: 'a', done: true, priority: 1, startAt: DateTime(2025, 1, 1));
    final b = FakeTask(key: 2, title: 'b', done: false, priority: 5, startAt: DateTime(2025, 1, 2));
    expect(TestGoalTreeAdapter.taskSort(a, b) > 0, true); // done goes after

    final c = FakeTask(key: 3, title: 'c', done: false, priority: 1, startAt: DateTime(2025, 1, 2));
    final d = FakeTask(key: 4, title: 'd', done: false, priority: 3, startAt: DateTime(2025, 1, 1));
    expect(TestGoalTreeAdapter.taskSort(c, d) < 0, true); // priority 1 before 3
  });
}

