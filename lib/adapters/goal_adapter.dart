import 'package:flutter/foundation.dart';

import '../providers/goal_provider.dart' as gp;
import '../providers/task_provider.dart' as tp;

/// UI 层使用的轻量 VM
class GoalVM {
  final int id; // Hive key
  final String title;

  /// 1(最高) ~ 5
  final int priority;

  /// 目标颜色（ARGB int / 0xFFxxxxxx），可为空
  final int? color;

  /// 0..1（按任务完成数）
  final double progress;

  final int tasksCount;
  final int doneCount;

  const GoalVM({
    required this.id,
    required this.title,
    required this.priority,
    required this.progress,
    required this.tasksCount,
    required this.doneCount,
    this.color,
  });
}

class GoalAdapter extends ChangeNotifier {
  final gp.GoalProvider goals;
  final tp.TaskProvider tasks;

  GoalAdapter(this.goals, this.tasks) {
    goals.addListener(_relay);
    tasks.addListener(_relay);
  }

  void _relay() => notifyListeners();

  /// 默认按 priority 排序（priority 小的在前）
  /// 若 priority 相同，可按 createdAt 或 title 再排序（这里先按 title）
  List<GoalVM> get goalsVM {
    final list = goals.goals.map((g) {
      final int key = _safeKey(g) ?? -1;
      final taskList = key == -1 ? const [] : tasks.tasksByGoal(key);

      final total = taskList.length;
      final done = taskList.where((t) => t.done).length;
      final progress =
          total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0).toDouble();

      return GoalVM(
        id: key,
        title: g.title,
        priority: g.priority,
        color: g.color,
        progress: progress,
        tasksCount: total,
        doneCount: done,
      );
    }).where((vm) => vm.id != -1).toList();

    list.sort((a, b) {
      final p = a.priority.compareTo(b.priority);
      if (p != 0) return p;
      // secondary sort
      return a.title.compareTo(b.title);
    });

    return list;
  }
}

int? _safeKey(Object o) {
  try {
    final k = (o as dynamic).key;
    if (k is int) return k;
  } catch (_) {}
  return null;
}

