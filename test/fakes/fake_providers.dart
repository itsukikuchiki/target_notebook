import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'fake_models.dart';

class FakeGoalProvider extends ChangeNotifier {
  final List<FakeGoal> _goals = [];
  List<FakeGoal> get goalsSorted {
    final list = [..._goals];
    list.sort((a, b) {
      final p = a.priority.compareTo(b.priority);
      if (p != 0) return p;
      return a.title.compareTo(b.title);
    });
    return list;
  }

  void seedGoals(List<FakeGoal> goals) {
    _goals
      ..clear()
      ..addAll(goals);
    notifyListeners();
  }

  int effectiveColorInt(FakeGoal g, {int? goalKey, int seed = 0}) {
    if (g.color != null) return g.color!;
    const defaults = <int>[
      0xFFEF5350, 0xFFAB47BC, 0xFF5C6BC0, 0xFF29B6F6, 0xFF26A69A,
      0xFF66BB6A, 0xFFFFCA28, 0xFFFFA726, 0xFF8D6E63, 0xFF78909C,
    ];
    final base = (goalKey ?? g.key) + seed;
    return defaults[base.abs() % defaults.length];
  }
}

class FakeSubGoalProvider extends ChangeNotifier {
  final List<FakeSubGoal> _subs = [];
  void seedSubGoals(List<FakeSubGoal> subs) {
    _subs
      ..clear()
      ..addAll(subs);
    notifyListeners();
  }

  List<FakeSubGoal> subGoalsByGoal(int goalId) =>
      _subs.where((s) => s.goalId == goalId).toList();
}

class FakeTaskProvider extends ChangeNotifier {
  final List<FakeTask> _tasks = [];
  void seedTasks(List<FakeTask> tasks) {
    _tasks
      ..clear()
      ..addAll(tasks);
    notifyListeners();
  }

  List<FakeTask> tasksByGoal(int goalId) =>
      _tasks.where((t) => t.goalId == goalId).toList();

  List<FakeTask> tasksBySubGoal(int subGoalId) =>
      _tasks.where((t) => t.subGoalId == subGoalId).toList();

  // 用于 Daily 周条取点：按 day 范围（start/end/deadline）粗略归属
  List<FakeTask> tasksForDate(DateTime day) {
    final s = DateTime(day.year, day.month, day.day, 0, 0);
    final e = DateTime(day.year, day.month, day.day, 23, 59, 59);

    bool belongs(FakeTask t) {
      final sa = t.startAt;
      final ea = t.endAt;
      if (sa != null || ea != null) {
        final a = sa ?? ea!;
        final b = ea ?? sa!;
        return !a.isAfter(e) && !b.isBefore(s);
      }
      final anchor = t.deadline;
      if (anchor == null) return false;
      return !anchor.isBefore(s) && !anchor.isAfter(e);
    }

    return _tasks.where(belongs).toList();
  }
}

