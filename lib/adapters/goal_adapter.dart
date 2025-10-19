import 'package:flutter/foundation.dart';
import '../providers/goal_provider.dart' as phase1;
import '../providers/task_provider.dart' as phase1;

class GoalVM {
  final int id;               // Hive key
  final String title;
  final double progress;      // 0..1
  final int tasksCount;
  final int doneCount;
  const GoalVM({
    required this.id,
    required this.title,
    required this.progress,
    required this.tasksCount,
    required this.doneCount,
  });
}

class GoalAdapter extends ChangeNotifier {
  final phase1.GoalProvider goals;
  final phase1.TaskProvider tasks;
  GoalAdapter(this.goals, this.tasks) {
    goals.addListener(_relay);
    tasks.addListener(_relay);
  }
  void _relay() => notifyListeners();

  List<GoalVM> get goalsVM {
    return goals.goals.map((g) {
      final int key = _safeKey(g) ?? -1;
      final taskList = key == -1 ? const [] : tasks.tasksByGoal(key);
      final total = taskList.length;
      final done  = taskList.where((t) => t.done).length;
      final progress = total == 0 ? 0.0 : (done / total).clamp(0, 1).toDouble();
      return GoalVM(
        id: key,
        title: g.title,
        progress: progress,
        tasksCount: total,
        doneCount: done,
      );
    }).toList();
  }
}

int? _safeKey(Object o) {
  try { final k = (o as dynamic).key; if (k is int) return k; } catch (_) {}
  return null;
}

