import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/goal.dart';
import '../models/sub_goal.dart';
import '../models/task.dart';

import '../providers/goal_provider.dart';
import '../providers/sub_goal_provider.dart';
import '../providers/task_provider.dart';

/// =======================
/// Tree View Models
/// =======================

class GoalNode {
  final int goalKey;
  final Goal goal;
  final Color color;

  final List<SubGoalNode> subGoals;
  final List<Task> directTasks;

  final int totalTasks;
  final int doneTasks;

  double get progress => totalTasks == 0 ? 0.0 : doneTasks / totalTasks;

  GoalNode({
    required this.goalKey,
    required this.goal,
    required this.color,
    required this.subGoals,
    required this.directTasks,
    required this.totalTasks,
    required this.doneTasks,
  });
}

class SubGoalNode {
  final int subGoalKey;
  final SubGoal subGoal;
  final Color color;
  final List<Task> tasks;

  SubGoalNode({
    required this.subGoalKey,
    required this.subGoal,
    required this.color,
    required this.tasks,
  });
}

/// =======================
/// Adapter
/// =======================

class GoalTreeAdapter extends ChangeNotifier {
  final GoalProvider goalP;
  final SubGoalProvider subGoalP;
  final TaskProvider taskP;

  GoalTreeAdapter(this.goalP, this.subGoalP, this.taskP) {
    goalP.addListener(_rebuild);
    subGoalP.addListener(_rebuild);
    taskP.addListener(_rebuild);
    _rebuild();
  }

  List<GoalNode> _goals = [];
  List<GoalNode> get goals => _goals;

  void _rebuild() {
    final sortedGoals = goalP.goalsSorted;
    final List<GoalNode> result = [];

    for (final g in sortedGoals) {
      final gKey = g.key;
      if (gKey is! int) continue;

      final goalColorInt = goalP.effectiveColorInt(g, goalKey: gKey);
      final goalColor = Color(goalColorInt);

      final subGoals = subGoalP.subGoalsByGoal(gKey);
      final allTasks = taskP.tasksByGoal(gKey);

      int total = 0;
      int done = 0;

      final subNodes = <SubGoalNode>[];

      // ---------- SubGoals ----------
      for (final sg in subGoals) {
        final sgKey = sg.key;
        if (sgKey is! int) continue;

        final sgTasks = taskP.tasksBySubGoal(sgKey).toList()
          ..sort(GoalTreeAdapter.taskSort);

        total += sgTasks.length;
        done += sgTasks.where((t) => t.done).length;

        subNodes.add(
          SubGoalNode(
            subGoalKey: sgKey,
            subGoal: sg,
            color: Color(sg.color ?? goalColorInt),
            tasks: sgTasks,
          ),
        );
      }

      // ---------- Direct Tasks ----------
      final directTasks = allTasks.where((t) => t.subGoalId == null).toList()
        ..sort(GoalTreeAdapter.taskSort);

      total += directTasks.length;
      done += directTasks.where((t) => t.done).length;

      result.add(
        GoalNode(
          goalKey: gKey,
          goal: g,
          color: goalColor,
          subGoals: subNodes,
          directTasks: directTasks,
          totalTasks: total,
          doneTasks: done,
        ),
      );
    }

    _goals = result;
    notifyListeners();
  }

  /// 统一任务排序规则（My Journey / Insight / 日历都能复用）
  static int taskSort(Task a, Task b) {
    // 1) 未完成优先
    if (a.done != b.done) return a.done ? 1 : -1;

    // 2) priority 小的更重要
    final p = a.priority.compareTo(b.priority);
    if (p != 0) return p;

    // 3) 时间
    final da = a.startAt ?? a.deadline ?? DateTime(2100);
    final db = b.startAt ?? b.deadline ?? DateTime(2100);
    return da.compareTo(db);
  }

  @override
  void dispose() {
    goalP.removeListener(_rebuild);
    subGoalP.removeListener(_rebuild);
    taskP.removeListener(_rebuild);
    super.dispose();
  }
}

