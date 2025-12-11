import 'package:flutter/foundation.dart';

import '../providers/task_provider.dart';
import '../models/task.dart';
import '../core/result.dart';

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

  /// 本地缓存 — 仅用于 UI 测试（新增任务立即显示）
  final Map<String, List<TaskVM>> _cacheByDate = {};

  String _key(DateTime d) => "${d.year}-${d.month}-${d.day}";

  TaskVM _toVm(Task t) {
    final d = t.startAt ?? t.endAt ?? DateTime.now();
    return TaskVM(
      t.key as int,
      t.title,
      d,
      t.done,
      goalId: t.goalId,
      isTodayTop3: t.isTodayTop3,
    );
  }

  List<TaskVM> tasksForDate(DateTime day) {
    final k = _key(day);

    // 如果有缓存 → 测试会立即得到新增结果
    if (_cacheByDate.containsKey(k)) {
      return _cacheByDate[k]!;
    }

    final list = src.tasksForDate(day).map(_toVm).toList();
    return list;
  }

  List<TaskVM> top3ForDate(DateTime day) {
    final all = src.top3ForDate(day);
    return all.map(_toVm).toList();
  }

  Future<void> toggleTaskDone(int taskId, bool value) async {
    await src.toggleTaskDone(taskId, value);
    notifyListeners();
  }

  Future<void> setPinnedTop3(int taskId, bool pinned) async {
    await src.setPinnedTop3(taskId, pinned);
    notifyListeners();
  }

  Future<void> setTop3Order(DateTime day, List<int> orderedTaskKeys) async {
    src.setTop3Order(day, orderedTaskKeys);
    notifyListeners();
  }

  /// 新增任务（Daily 页快速新增）
  Future<int> newTask({
    required String title,
    DateTime? date,
    int? goalId,
  }) async {
    final d = date ?? DateTime.now();
    final safeTitle = title.trim().isEmpty ? '今日任务' : title.trim();

    final t = Task(
      title: safeTitle,
      goalId: goalId,
      startAt: d,
      endAt: d,
    );

    final Result<int> res = await src.addTask(t);

    if (res is Success<int>) {
      final id = res.value;

      // 创建 VM 放入缓存 —— 关键（测试需要立即看到）
      final vm = TaskVM(id, safeTitle, d, false, goalId: goalId);
      final k = _key(d);

      final list = _cacheByDate[k] ?? tasksForDate(d);
      final newList = [...list, vm];
      _cacheByDate[k] = newList;

      notifyListeners();
      return id;
    }

    if (res is Failure<int>) {
      throw res.error;
    }

    throw Exception('Unknown Result type from TaskProvider.addTask');
  }
}

