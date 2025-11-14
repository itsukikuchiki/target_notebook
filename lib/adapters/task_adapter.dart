import 'package:flutter/foundation.dart';
import '../providers/task_provider.dart';
import '../models/task.dart';

/// UI 层使用的轻量 VM（避免直接暴露 Hive 对象）
class TaskVM {
  final int id;
  final String title;
  final DateTime date;
  final bool done;
  final int? goalId;
  final bool isTodayTop3;

  const TaskVM(
    this.id,
    this.title,
    this.date,
    this.done, {
    this.goalId,
    this.isTodayTop3 = false,
  });
}

class TaskAdapter with ChangeNotifier {
  final TaskProvider src;
  TaskAdapter(this.src);

  List<TaskVM> tasksForDate(DateTime day) {
    final list = src.tasksForDate(day);
    return list.map((t) {
      final d = t.startAt ?? t.endAt ?? DateTime.now();
      return TaskVM(
        t.key as int,
        t.title,
        d,
        t.done,
        goalId: t.goalId,
        isTodayTop3: t.isTodayTop3,
      );
    }).toList();
  }

  List<TaskVM> top3ForDate(DateTime day) {
    final all = src.top3ForDate(day);
    return all.map((t) {
      final d = t.startAt ?? t.endAt ?? DateTime.now();
      return TaskVM(
        t.key as int,
        t.title,
        d,
        t.done,
        goalId: t.goalId,
        isTodayTop3: t.isTodayTop3,
      );
    }).toList();
  }

  Future<void> toggleTaskDone(int taskId, bool value) async {
    await src.toggleTaskDone(taskId, value);
    notifyListeners();
  }

  Future<void> setPinnedTop3(int taskId, bool pinned) async {
    await src.setPinnedTop3(taskId, pinned);
    notifyListeners();
  }

  void setTop3Order(DateTime day, List<int> orderedTaskKeys) {
    src.setTop3Order(day, orderedTaskKeys);
    notifyListeners();
  }
}

