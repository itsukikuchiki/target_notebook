import 'dart:convert';

import 'package:flutter/material.dart'; // DateUtils
import 'package:hive/hive.dart';

import '../core/hive_init.dart'; // AppBoxes
import '../core/result.dart'; // Result / Success / Failure
import '../models/task.dart';
import '../common/utils/date_utils.dart' as du; // startOfDay / endOfDay
import '../utils/hive_initializer.dart'; // ensureTypedBox

import '../services/notification_local_service.dart';

class TaskProvider extends ChangeNotifier {
  late Box<Task> _taskBox;

  NotificationLocalService? _notification;

  final Map<DateTime, List<int>> _top3OrderByDay = {};

  /// ✅ 关键：缓存“上一次已知的 alarm 快照”，避免 Hive 返回同引用时 before 被污染
  final Map<int, _TaskSnapshot> _lastSnapshotByKey = <int, _TaskSnapshot>{};

  Future<void> init({
    Box<Task>? taskBox,
    String boxName = AppBoxes.task,
    NotificationLocalService? notification,
  }) async {
    _taskBox = taskBox ?? await ensureTypedBox<Task>(boxName);
    if (notification != null) {
      _notification = notification;
    }
  }

  void bindNotificationService(NotificationLocalService service) {
    _notification = service;
  }

  // =========================
  // Query
  // =========================
  Task? getByKey(int key) => _taskBox.get(key);

  List<Task> tasksByGoal(int goalId) =>
      _taskBox.values.where((t) => t.goalId == goalId).toList();

  List<Task> tasksBySubGoal(int subGoalId) =>
      _taskBox.values.where((t) => t.subGoalId == subGoalId).toList();

  List<Task> tasksForDate(DateTime day) {
    final s = du.startOfDay(day);
    final e = du.endOfDay(day);

    final list = _taskBox.values.where((t) => _belongsToRange(t, s, e)).toList();
    list.sort(_taskSort);
    return list;
  }

  List<Task> tasksForDay(DateTime day) => tasksForDate(day);

  List<Task> tasksForRange(DateTime start, DateTime end) {
    final s = du.startOfDay(start);
    final e = du.endOfDay(end);

    final list = _taskBox.values.where((t) => _belongsToRange(t, s, e)).toList();
    list.sort(_taskSort);
    return list;
  }

  List<Task> top3ForDate(DateTime day) {
    final s = du.startOfDay(day);
    final e = du.endOfDay(day);

    final all = _taskBox.values.where((t) => _belongsToRange(t, s, e)).toList();

    final pinned = all.where((t) => t.isTodayTop3 && !t.done).toList();
    final rest = all.where((t) => !t.isTodayTop3 && !t.done).toList();

    pinned.sort(_top3Sort);
    rest.sort(_top3Sort);

    final picked = [...pinned, ...rest].take(3).toList();

    final order = _top3OrderByDay[DateUtils.dateOnly(day)];
    if (order == null) return picked;

    picked.sort((a, b) {
      final ka = a.key;
      final kb = b.key;
      final ia = (ka is int) ? order.indexOf(ka) : -1;
      final ib = (kb is int) ? order.indexOf(kb) : -1;
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

    final before = _lastSnapshotByKey[taskKey] ?? _snapshot(t);

    t.isTodayTop3 = pinned;
    await t.save();

    await _syncAlarmForUpdate(
      taskKey: taskKey,
      before: before,
      after: t,
      cancelIfDone: true,
    );

    _lastSnapshotByKey[taskKey] = _snapshot(t);

    notifyListeners();
  }

  void setTop3Order(DateTime day, List<int> orderedTaskKeys) {
    _top3OrderByDay[DateUtils.dateOnly(day)] = List.of(orderedTaskKeys);
    notifyListeners();
  }

  Future<void> toggleTaskDone(int key, bool value) async {
    final t = _taskBox.get(key);
    if (t == null) return;

    final before = _lastSnapshotByKey[key] ?? _snapshot(t);

    t.done = value;
    if (value) t.completion = 1.0;

    await t.save();

    await _syncAlarmForUpdate(
      taskKey: key,
      before: before,
      after: t,
      cancelIfDone: true,
    );

    _lastSnapshotByKey[key] = _snapshot(t);

    notifyListeners();
  }

  Future<void> toggleDone(int key) async {
    final t = _taskBox.get(key);
    if (t == null) return;

    final before = _lastSnapshotByKey[key] ?? _snapshot(t);

    t.done = !t.done;
    if (t.done) t.completion = 1.0;

    await t.save();

    await _syncAlarmForUpdate(
      taskKey: key,
      before: before,
      after: t,
      cancelIfDone: true,
    );

    _lastSnapshotByKey[key] = _snapshot(t);

    notifyListeners();
  }

  // =========================
  // Create
  // =========================

  Future<Result<int>> addTask(Task t) async {
    try {
      final key = await _taskBox.add(t);

      final created = _taskBox.get(key);
      if (created != null) {
        await _syncAlarmForCreate(taskKey: key, task: created);
        _lastSnapshotByKey[key] = _snapshot(created);
      }

      notifyListeners();
      return Success(key);
    } catch (e, s) {
      return Failure(Exception('addTask failed: $e'), s);
    }
  }

  Future<int> addQuickTaskToday(String title, {int? goalId}) async {
    final now = DateTime.now();
    final t = Task(
      title: title.trim().isEmpty ? '今日任务' : title.trim(),
      goalId: goalId,
      startAt: now,
      endAt: now,
    );

    final key = await _taskBox.add(t);

    final created = _taskBox.get(key);
    if (created != null) {
      await _syncAlarmForCreate(taskKey: key, task: created);
      _lastSnapshotByKey[key] = _snapshot(created);
    }

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

    final created = _taskBox.get(key);
    if (created != null) {
      await _syncAlarmForCreate(taskKey: key, task: created);
      _lastSnapshotByKey[key] = _snapshot(created);
    }

    notifyListeners();
    return key;
  }

  // =========================
  // Update / Delete
  // =========================

  Future<Result<void>> updateTaskResult(int key, Task patch) async {
    try {
      final t = _taskBox.get(key);
      if (t == null) return Failure(Exception('Task not found: $key'));

      final before = _lastSnapshotByKey[key] ?? _snapshot(t);

      _applyPatch(t, patch);
      await t.save();

      await _syncAlarmForUpdate(
        taskKey: key,
        before: before,
        after: t,
        cancelIfDone: true,
      );

      _lastSnapshotByKey[key] = _snapshot(t);

      notifyListeners();
      return const Success(null);
    } catch (e, s) {
      return Failure(Exception('updateTask failed: $e'), s);
    }
  }

  /// ✅ 兼容旧调用：支持直接传 Hive 对象
  /// - before 一律来自 provider 的 lastSnapshot（可穿透“测试提前 mutate Hive 对象”）
  /// - update 后会 ensure schedule（幂等），满足你的测试“第一次 update 就触发 schedule”
  Future<void> updateTask(Task task) async {
    final key = task.key;
    if (key is! int) return;

    final current = _taskBox.get(key);
    if (current == null) return;

    final before = _lastSnapshotByKey[key] ?? _snapshot(Task.fromMap(current.toMap()));

    _applyPatch(current, task);
    await current.save();

    await _syncAlarmForUpdate(
      taskKey: key,
      before: before,
      after: current,
      cancelIfDone: true,
    );

    _lastSnapshotByKey[key] = _snapshot(current);

    notifyListeners();
  }

  Future<Result<void>> deleteTaskResult(int key) async {
    try {
      await _notification?.cancel(key);
      await _taskBox.delete(key);
      _lastSnapshotByKey.remove(key);
      notifyListeners();
      return const Success(null);
    } catch (e, s) {
      return Failure(Exception('deleteTask failed: $e'), s);
    }
  }

  Future<void> deleteTask(int key) async {
    await _notification?.cancel(key);
    await _taskBox.delete(key);
    _lastSnapshotByKey.remove(key);
    notifyListeners();
  }

  Future<void> cancelAllAlarms() async {
    await _notification?.cancelAll();
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

        int savedKey;
        if (key != null) {
          await _taskBox.put(key, t);
          savedKey = key;
        } else {
          savedKey = await _taskBox.add(t);
        }

        final saved = _taskBox.get(savedKey);
        if (saved != null) {
          await _syncAlarmForCreate(taskKey: savedKey, task: saved);
          _lastSnapshotByKey[savedKey] = _snapshot(saved);
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

  int _taskSort(Task a, Task b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    if (a.priority != b.priority) return a.priority.compareTo(b.priority);

    final da = a.deadline;
    final db = b.deadline;
    if (da != null || db != null) {
      return (da ?? DateTime(2100)).compareTo(db ?? DateTime(2100));
    }

    final sa = a.startAt ?? a.endAt ?? DateTime(2100);
    final sb = b.startAt ?? b.endAt ?? DateTime(2100);
    return sa.compareTo(sb);
  }

  int _top3Sort(Task a, Task b) {
    if (a.priority != b.priority) return a.priority.compareTo(b.priority);

    final da = a.deadline ?? DateTime(2100);
    final db = b.deadline ?? DateTime(2100);
    if (da != db) return da.compareTo(db);

    final sa = a.startAt ?? DateTime(2100);
    final sb = b.startAt ?? DateTime(2100);
    return sa.compareTo(sb);
  }

  bool _belongsToRange(Task t, DateTime start, DateTime end) {
    final sa = t.startAt;
    final ea = t.endAt;

    if (sa != null || ea != null) {
      final a = sa ?? ea!;
      final b = ea ?? sa!;
      return !a.isAfter(end) && !b.isBefore(start);
    }

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

  _TaskSnapshot _snapshot(Task t) => _TaskSnapshot(
        hasAlarm: t.hasAlarm,
        alarmAt: t.alarmAt,
        title: t.title,
        note: t.note,
        done: t.done,
      );

  Future<void> _syncAlarmForCreate({
    required int taskKey,
    required Task task,
  }) async {
    final service = _notification;
    if (service == null) return;

    if (task.done) return;

    if (task.hasAlarm == true && task.alarmAt != null) {
      await service.scheduleOne(
        id: taskKey,
        at: task.alarmAt!,
        title: task.title,
        body: (task.note != null && task.note!.trim().isNotEmpty)
            ? task.note!.trim()
            : '提醒时间到了',
      );
    }
  }

  /// ✅ 新策略：
  /// - done -> 必 cancel
  /// - afterEnabled=true -> “确保已 schedule”（幂等），满足测试“第一次 update 就 schedule”
  /// - beforeEnabled=true 且 changed -> cancel + schedule（满足 reschedule 测试）
  Future<void> _syncAlarmForUpdate({
    required int taskKey,
    required _TaskSnapshot before,
    required Task after,
    required bool cancelIfDone,
  }) async {
    final service = _notification;
    if (service == null) return;

    if (cancelIfDone && after.done) {
      await service.cancel(taskKey);
      return;
    }

    final beforeEnabled = before.hasAlarm == true && before.alarmAt != null;
    final afterEnabled = after.hasAlarm == true && after.alarmAt != null;

    if (beforeEnabled && !afterEnabled) {
      await service.cancel(taskKey);
      return;
    }

    if (!afterEnabled) return;

    final body = (after.note != null && after.note!.trim().isNotEmpty)
        ? after.note!.trim()
        : '提醒时间到了';

    if (!beforeEnabled) {
      // 之前没启用，现在启用：直接 schedule
      await service.scheduleOne(
        id: taskKey,
        at: after.alarmAt!,
        title: after.title,
        body: body,
      );
      return;
    }

    // beforeEnabled && afterEnabled
    final changedAt =
        before.alarmAt!.millisecondsSinceEpoch != after.alarmAt!.millisecondsSinceEpoch;
    final changedTitle = before.title != after.title;
    final changedBody = (before.note ?? '').trim() != (after.note ?? '').trim();

    if (changedAt || changedTitle || changedBody) {
      await service.cancel(taskKey);
      await service.scheduleOne(
        id: taskKey,
        at: after.alarmAt!,
        title: after.title,
        body: body,
      );
      return;
    }

    // ✅ 没变化也确保 schedule（幂等，覆盖/重复 schedule 也没关系）
    await service.scheduleOne(
      id: taskKey,
      at: after.alarmAt!,
      title: after.title,
      body: body,
    );
  }
}

class _TaskSnapshot {
  final bool? hasAlarm;
  final DateTime? alarmAt;
  final String title;
  final String? note;
  final bool done;

  _TaskSnapshot({
    required this.hasAlarm,
    required this.alarmAt,
    required this.title,
    required this.note,
    required this.done,
  });
}

