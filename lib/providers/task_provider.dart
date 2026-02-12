import 'dart:convert';

import 'package:flutter/material.dart'; // DateUtils
import 'package:hive/hive.dart';

import '../core/hive_init.dart'; // AppBoxes
import '../core/result.dart'; // Result / Success / Failure
import '../models/task.dart';
import '../common/utils/date_utils.dart' as du; // startOfDay / endOfDay
import '../utils/hive_initializer.dart'; // ensureTypedBox

class TaskProvider extends ChangeNotifier {
  late Box<Task> _taskBox;

  /// 记录每天 Top3 的拖拽顺序（key 列表）
  final Map<DateTime, List<int>> _top3OrderByDay = {};

  Future<void> init({
    Box<Task>? taskBox,
    String boxName = AppBoxes.task,
  }) async {
    _taskBox = taskBox ?? await ensureTypedBox<Task>(boxName);
  }

  // =========================
  // Query
  // =========================
  /// 通过 Hive key 获取 Task
  Task? getByKey(int key) => _taskBox.get(key);

  /// 某目标下任务
  List<Task> tasksByGoal(int goalId) =>
      _taskBox.values.where((t) => t.goalId == goalId).toList();

  /// 某子目标下任务
  List<Task> tasksBySubGoal(int subGoalId) =>
      _taskBox.values.where((t) => t.subGoalId == subGoalId).toList();

  /// 某日期任务（未完成优先，按 startAt 排序）
  List<Task> tasksForDate(DateTime day) {
    final s = du.startOfDay(day);
    final e = du.endOfDay(day);

    final list = _taskBox.values.where((t) => _belongsToRange(t, s, e)).toList();

    list.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1; // 未完成在前
      // priority：小的更优先（1最高）
      if (a.priority != b.priority) return a.priority.compareTo(b.priority);
      final sa = a.startAt ?? a.deadline ?? DateTime(2100);
      final sb = b.startAt ?? b.deadline ?? DateTime(2100);
      return sa.compareTo(sb);
    });
    return list;
  }

  /// 兼容旧命名
  List<Task> tasksForDay(DateTime day) => tasksForDate(day);

  /// 新增：范围查询（用于 week/月视图 eventLoader 或批量点展示）
  /// 规则：
  /// - 如果任务有 startAt/endAt：与 range 有交集则算入
  /// - 否则使用 deadline 或 dateAnchor（startAt??deadline）落在 range 内算入
  List<Task> tasksForRange(DateTime start, DateTime end) {
    final s = du.startOfDay(start);
    final e = du.endOfDay(end);

    final list = _taskBox.values.where((t) => _belongsToRange(t, s, e)).toList();

    list.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      if (a.priority != b.priority) return a.priority.compareTo(b.priority);
      final da = a.startAt ?? a.deadline ?? a.endAt ?? DateTime(2100);
      final db = b.startAt ?? b.deadline ?? b.endAt ?? DateTime(2100);
      return da.compareTo(db);
    });

    return list;
  }

  /// 今日三件事（固定优先，不足补未完成）+ 应用拖拽序
  List<Task> top3ForDate(DateTime day) {
    final s = du.startOfDay(day);
    final e = du.endOfDay(day);

    final all =
        _taskBox.values.where((t) => _belongsToRange(t, s, e)).toList();

    final pinned = all.where((t) => t.isTodayTop3 && !t.done).toList();
    final rest = all.where((t) => !t.isTodayTop3 && !t.done).toList();

    // pinned 里也按 priority 排一下更合理
    pinned.sort((a, b) => a.priority.compareTo(b.priority));
    rest.sort((a, b) => a.priority.compareTo(b.priority));

    final picked = [...pinned, ...rest].take(3).toList();

    final order = _top3OrderByDay[DateUtils.dateOnly(day)];
    if (order == null) return picked;

    picked.sort((a, b) {
      final ia = order.indexOf(a.key as int);
      final ib = order.indexOf(b.key as int);
      return (ia == -1 ? 999 : ia).compareTo(ib == -1 ? 999 : ib);
    });
    return picked;
  }

  // =========================
  // Top3 / Done
  // =========================

  Future<void> setPinnedTop3(int taskKey, bool pinned) async {
    final t = _taskBox.get(taskKey);
    if (t == null) return;
    t.isTodayTop3 = pinned;
    await t.save();
    notifyListeners();
  }

  void setTop3Order(DateTime day, List<int> orderedTaskKeys) {
    _top3OrderByDay[DateUtils.dateOnly(day)] = List.of(orderedTaskKeys);
    notifyListeners();
  }

  Future<void> toggleTaskDone(int key, bool value) async {
    final t = _taskBox.get(key);
    if (t == null) return;
    t.done = value;
    // done=true 时可以顺便把 completion 归 1.0（可选，但更一致）
    if (value) t.completion = 1.0;
    await t.save();
    notifyListeners();
  }

  Future<void> toggleDone(int key) async {
    final t = _taskBox.get(key);
    if (t == null) return;
    t.done = !t.done;
    if (t.done) t.completion = 1.0;
    await t.save();
    notifyListeners();
  }

  // =========================
  // Create
  // =========================

  Future<Result<int>> addTask(Task t) async {
    try {
      final key = await _taskBox.add(t);
      notifyListeners();
      return Success(key);
    } catch (e, s) {
      return Failure(Exception('addTask failed: $e'), s);
    }
  }

  /// 兼容：快速新增（旧逻辑保留）
  Future<int> addQuickTaskToday(String title, {int? goalId}) async {
    final now = DateTime.now();
    final t = Task(
      title: title.trim().isEmpty ? '今日任务' : title.trim(),
      goalId: goalId,
      startAt: now,
      endAt: now,
    );
    final key = await _taskBox.add(t);
    notifyListeners();
    return key;
  }

  Future<int> createTask({
    required String title,
    DateTime? date,
    int? goalId,
  }) async {
    final d = date ?? DateTime.now();
    final t = Task(
      title: title.trim().isEmpty ? '新任务' : title.trim(),
      goalId: goalId,
      startAt: d,
      endAt: d,
    );
    final key = await _taskBox.add(t);
    notifyListeners();
    return key;
  }

  // =========================
  // Update / Delete (Result版 + UI友好版)
  // =========================

  /// Result 版：按 key patch（你旧代码的风格）
  Future<Result<void>> updateTaskResult(int key, Task patch) async {
    try {
      final t = _taskBox.get(key);
      if (t == null) return Failure(Exception('Task not found: $key'));

      _applyPatch(t, patch);
      await t.save();
      notifyListeners();
      return const Success(null);
    } catch (e, s) {
      return Failure(Exception('updateTask failed: $e'), s);
    }
  }

  /// UI 友好版：直接传 Task（必须已是 HiveObject，且有 key）
  /// 这就是你 `TaskAdapter.updateTask(Task task)` 想要调用的接口
  Future<void> updateTask(Task task) async {
    final key = task.key;
    if (key is! int) return;

    final current = _taskBox.get(key);
    if (current == null) return;

    // 用传入 task 当 patch，避免 UI 和存储字段遗漏
    _applyPatch(current, task);
    await current.save();
    notifyListeners();
  }

  /// Result 版删除（旧逻辑）
  Future<Result<void>> deleteTaskResult(int key) async {
    try {
      await _taskBox.delete(key);
      notifyListeners();
      return const Success(null);
    } catch (e, s) {
      return Failure(Exception('deleteTask failed: $e'), s);
    }
  }

  /// UI 友好版删除（你 Adapter 里直接 await src.deleteTask(taskId)）
  Future<void> deleteTask(int key) async {
    await _taskBox.delete(key);
    notifyListeners();
  }

  // =========================
  // Export / Import
  // =========================

  String exportAllToJson() {
    final list = _taskBox.keys.map((k) {
      final t = _taskBox.get(k as int)!;
      return {'key': k, 'data': t.toMap()};
    }).toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }

  Future<Result<int>> importFromJson(String json) async {
    try {
      final decoded = jsonDecode(json) as List<dynamic>;
      int count = 0;
      for (final e in decoded) {
        final map = Map<String, dynamic>.from(e as Map);
        final key = map['key'] as int?;
        final t = Task.fromMap(Map<String, dynamic>.from(map['data'] as Map));
        if (key != null) {
          await _taskBox.put(key, t);
        } else {
          await _taskBox.add(t);
        }
        count++;
      }
      notifyListeners();
      return Success(count);
    } catch (e, s) {
      return Failure(Exception('import tasks failed: $e'), s);
    }
  }

  // =========================
  // Internal helpers
  // =========================

  bool _belongsToRange(Task t, DateTime start, DateTime end) {
    final sa = t.startAt;
    final ea = t.endAt;

    // 1) 有 start/end：按区间交集判断
    if (sa != null || ea != null) {
      final a = sa ?? ea!;
      final b = ea ?? sa!;
      // 交集：a <= end && b >= start
      return !a.isAfter(end) && !b.isBefore(start);
    }

    // 2) 无 start/end：用 deadline 或 dateAnchor
    final anchor = t.deadline ?? t.dateAnchor;
    if (anchor == null) return false;
    return !anchor.isBefore(start) && !anchor.isAfter(end);
  }

  void _applyPatch(Task dst, Task patch) {
    dst
      ..title = patch.title
      ..note = patch.note
      ..goalId = patch.goalId
      ..subGoalId = patch.subGoalId
      ..startAt = patch.startAt
      ..endAt = patch.endAt
      ..done = patch.done
      ..isTodayTop3 = patch.isTodayTop3

      // W5
      ..priority = patch.priority
      ..isAllDay = patch.isAllDay
      ..location = patch.location
      ..participantEmailsRaw = patch.participantEmailsRaw
      ..hasAlarm = patch.hasAlarm
      ..alarmAt = patch.alarmAt
      ..iconKey = patch.iconKey
      ..completion = patch.completion
      ..deadline = patch.deadline
      ..photoPath = patch.photoPath
      ..color = patch.color;
  }
}

