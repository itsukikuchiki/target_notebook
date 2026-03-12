// lib/adapters/task_adapter.dart
import 'package:flutter/foundation.dart';

import '../providers/task_provider.dart';
import '../models/task.dart';
import '../core/result.dart';

class TaskVM {
  final int id;
  final String title;
  final DateTime date;
  final bool done;
  final int? goalId;
  final int? subGoalId;
  final bool isTodayTop3;

  final int priority;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool isAllDay;

  final String? location;
  final List<String> participantEmails;
  final double completion;
  final DateTime? deadline;

  final int? color;

  const TaskVM(
    this.id,
    this.title,
    this.date,
    this.done, {
    this.goalId,
    this.subGoalId,
    this.isTodayTop3 = false,
    this.priority = 3,
    this.startAt,
    this.endAt,
    this.isAllDay = false,
    this.location,
    this.participantEmails = const [],
    this.completion = 0.0,
    this.deadline,
    this.color,
  });
}

class TaskAdapter with ChangeNotifier {
  final TaskProvider src;

  /// 本地缓存 — 仅用于 UI 测试（新增任务立即显示）
  final Map<String, List<TaskVM>> _cacheByDate = {};

  TaskAdapter(this.src) {
    // ✅ 关键修复：provider 任何变更（update/delete/add/排序等）都清 cache，避免 ghost
    src.addListener(_onSrcChanged);
  }

  @override
  void dispose() {
    src.removeListener(_onSrcChanged);
    super.dispose();
  }

  void _onSrcChanged() {
    _cacheByDate.clear();
    notifyListeners();
  }

  String _key(DateTime d) => "${d.year}-${d.month}-${d.day}";

  DateTime _anchor(Task t) => t.startAt ?? t.deadline ?? t.endAt ?? DateTime.now();

  TaskVM _toVm(Task t) {
    final d = _anchor(t);
    return TaskVM(
      t.key as int,
      t.title,
      d,
      t.done,
      goalId: t.goalId,
      subGoalId: t.subGoalId,
      isTodayTop3: t.isTodayTop3,
      priority: t.priority,
      startAt: t.startAt,
      endAt: t.endAt,
      isAllDay: t.isAllDay,
      location: t.location,
      participantEmails: t.participantEmails,
      completion: t.effectiveCompletion,
      deadline: t.deadline,
      color: t.color,
    );
  }

  // =========================
  // Query APIs (Daily / Calendar)
  // =========================

  List<TaskVM> tasksForDate(DateTime day) {
    final k = _key(day);
    if (_cacheByDate.containsKey(k)) return _cacheByDate[k]!;

    final list = src.tasksForDate(day).map(_toVm).toList();
    return list;
  }

  List<TaskVM> top3ForDate(DateTime day) {
    final all = src.top3ForDate(day);
    return all.map(_toVm).toList();
  }

  List<TaskVM> tasksForRange(DateTime start, DateTime end) {
    final list = src.tasksForRange(start, end).map(_toVm).toList();
    return list;
  }

  bool hasAnyTaskOn(DateTime day) => tasksForDate(day).isNotEmpty;

  // =========================
  // Mutations
  // =========================

  Future<void> toggleTaskDone(int taskId, bool value) async {
    await src.toggleTaskDone(taskId, value);
    _cacheByDate.clear();
    notifyListeners();
  }

  Future<void> setPinnedTop3(int taskId, bool pinned) async {
    await src.setPinnedTop3(taskId, pinned);
    _cacheByDate.clear();
    notifyListeners();
  }

  Future<void> setTop3Order(DateTime day, List<int> orderedTaskKeys) async {
    src.setTop3Order(day, orderedTaskKeys);
    _cacheByDate.clear();
    notifyListeners();
  }

  Future<void> deleteTask(int taskId) async {
    await src.deleteTask(taskId);
    _cacheByDate.clear();
    notifyListeners();
  }

  Future<void> updateTask(Task task) async {
    await src.updateTask(task);
    // ✅ update 后清 cache（跨日期移动/字段变化都能正确反映）
    _cacheByDate.clear();
    notifyListeners();
  }

  // =========================
  // Create (Daily quick add)
  // =========================

  Future<int> newTask({
    required String title,
    DateTime? date,
    int? goalId,
    int? subGoalId,
    int priority = 3,
  }) async {
    final d = date ?? DateTime.now();
    final safeTitle = title.trim().isEmpty ? '今日任务' : title.trim();

    final t = Task(
      title: safeTitle,
      goalId: goalId,
      subGoalId: subGoalId,
      priority: priority,
      startAt: d,
      endAt: d,
      isAllDay: false,
    );

    final Result<int> res = await src.addTask(t);

    if (res is Success<int>) {
      final id = res.value;

      final vm = TaskVM(
        id,
        safeTitle,
        d,
        false,
        goalId: goalId,
        subGoalId: subGoalId,
        priority: priority,
        startAt: d,
        endAt: d,
      );

      final k = _key(d);
      final list = _cacheByDate[k] ?? src.tasksForDate(d).map(_toVm).toList();
      _cacheByDate[k] = [...list, vm];

      notifyListeners();
      return id;
    }

    if (res is Failure<int>) throw res.error;
    throw Exception('Unknown Result type from TaskProvider.addTask');
  }
}
