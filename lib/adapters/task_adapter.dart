import 'package:flutter/foundation.dart';

import '../providers/task_provider.dart';
import '../models/task.dart';
import '../core/result.dart';

/// UI 层使用的轻量 VM（避免直接暴露 Hive 对象）
/// - 保留原字段，新增 W5 需要的字段（可选）
/// - 旧 UI 不用改也能继续跑
class TaskVM {
  final int id;
  final String title;

  /// 日历/列表用的日期锚点（优先 startAt，其次 deadline，其次 now）
  final DateTime date;

  final bool done;
  final int? goalId;
  final int? subGoalId;

  /// 今日三件事（Pinned）
  final bool isTodayTop3;

  /// 新增：优先度（1最高）
  final int priority;

  /// 新增：时间字段（详情页/周视图会用）
  final DateTime? startAt;
  final DateTime? endAt;
  final bool isAllDay;

  /// 新增：地点/参与者/完成度/截止等（详情页会用）
  final String? location;
  final List<String> participantEmails;
  final double completion;
  final DateTime? deadline;

  /// 新增：颜色（普通日程颜色 or 覆盖色；目标联动颜色可在 UI 层由 goalId -> Goal.color 决定）
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
  TaskAdapter(this.src);

  /// 本地缓存 — 仅用于 UI 测试（新增任务立即显示）
  final Map<String, List<TaskVM>> _cacheByDate = {};

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

  /// 单日任务（旧接口保留）
  List<TaskVM> tasksForDate(DateTime day) {
    final k = _key(day);

    // 如果有缓存 → 测试会立即得到新增结果
    if (_cacheByDate.containsKey(k)) {
      return _cacheByDate[k]!;
    }

    final list = src.tasksForDate(day).map(_toVm).toList();
    return list;
  }

  /// Top3（旧接口保留）
  List<TaskVM> top3ForDate(DateTime day) {
    final all = src.top3ForDate(day);
    return all.map(_toVm).toList();
  }

  /// 新增：按范围取任务（用于 Calendar eventLoader / 周视图）
  /// 注意：是否精确到 startAt/endAt 的跨度，由 TaskProvider 决定
  List<TaskVM> tasksForRange(DateTime start, DateTime end) {
    final list = src.tasksForRange(start, end).map(_toVm).toList();
    return list;
  }

  /// 新增：用于日历“点”展示 —— 返回某一天是否有任务
  /// Calendar 组件一般会频繁调用，先用 provider 的 range 查询再做 group 会更快
  bool hasAnyTaskOn(DateTime day) {
    final list = tasksForDate(day);
    return list.isNotEmpty;
  }

  // =========================
  // Mutations
  // =========================

  Future<void> toggleTaskDone(int taskId, bool value) async {
    await src.toggleTaskDone(taskId, value);
    _invalidateCacheForTaskId(taskId);
    notifyListeners();
  }

  Future<void> setPinnedTop3(int taskId, bool pinned) async {
    await src.setPinnedTop3(taskId, pinned);
    _invalidateCacheForTaskId(taskId);
    notifyListeners();
  }

  Future<void> setTop3Order(DateTime day, List<int> orderedTaskKeys) async {
    src.setTop3Order(day, orderedTaskKeys);
    _invalidateCacheForDay(day);
    notifyListeners();
  }

  /// 新增：删除任务（12/14 必需）
  Future<void> deleteTask(int taskId) async {
    await src.deleteTask(taskId);
    _invalidateCacheForTaskId(taskId);
    notifyListeners();
  }

  /// 新增：更新任务（详情页保存）
  Future<void> updateTask(Task task) async {
    await src.updateTask(task);
    _invalidateCacheForDay(_anchor(task));
    notifyListeners();
  }

  // =========================
  // Create (Daily quick add)
  // =========================

  /// 新增任务（Daily 页快速新增）
  /// - 保持原行为：写入缓存，让测试立即看到
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
      // 默认非全日：如果你更倾向 all-day，可改为 true
      isAllDay: false,
    );

    final Result<int> res = await src.addTask(t);

    if (res is Success<int>) {
      final id = res.value;

      // 创建 VM 放入缓存 —— 关键（测试需要立即看到）
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
      final list = _cacheByDate[k] ?? tasksForDate(d);
      _cacheByDate[k] = [...list, vm];

      notifyListeners();
      return id;
    }

    if (res is Failure<int>) {
      throw res.error;
    }

    throw Exception('Unknown Result type from TaskProvider.addTask');
  }

  // =========================
  // Cache helpers
  // =========================

  void _invalidateCacheForDay(DateTime day) {
    _cacheByDate.remove(_key(day));
  }

  void _invalidateCacheForTaskId(int taskId) {
    // 简单粗暴：扫描所有缓存日期移除该 task
    // 缓存量很小（只用于测试/即时显示），O(n)可接受
    final keys = _cacheByDate.keys.toList(growable: false);
    for (final k in keys) {
      final list = _cacheByDate[k];
      if (list == null) continue;
      final newList = list.where((e) => e.id != taskId).toList();
      _cacheByDate[k] = newList;
    }
  }
}

