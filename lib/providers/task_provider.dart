import 'dart:convert';

import 'package:flutter/material.dart'; // 提供 DateUtils
import 'package:hive/hive.dart';

import '../core/hive_init.dart'; // 提供 AppBoxes
import '../core/result.dart'; // Result / Success / Failure
import '../models/task.dart';
import '../common/utils/date_utils.dart' as du; // 避免命名冲突
import '../utils/hive_initializer.dart'; // 提供 ensureTypedBox

class TaskProvider extends ChangeNotifier {
  late Box<Task> _taskBox;

  /// 记录每天 Top3 的拖拽顺序（key 列表）
  final Map<DateTime, List<int>> _top3OrderByDay = {};

  /// 初始化
  /// - 可注入 [taskBox]（测试方便）
  /// - 默认使用 [AppBoxes.task]
  Future<void> init({
    Box<Task>? taskBox,
    String boxName = AppBoxes.task,
  }) async {
    _taskBox = taskBox ?? await ensureTypedBox<Task>(boxName);
  }

  /// 某目标下任务
  List<Task> tasksByGoal(int goalId) =>
      _taskBox.values.where((t) => t.goalId == goalId).toList();

  /// 某日期任务（未完成优先）
  List<Task> tasksForDate(DateTime day) {
    final s = du.startOfDay(day);
    final e = du.endOfDay(day);

    final list = _taskBox.values.where((t) {
      final sa = t.startAt;
      final ea = t.endAt;
      final saIn = sa != null && !sa.isBefore(s) && !sa.isAfter(e);
      final eaIn = ea != null && !ea.isBefore(s) && !ea.isAfter(e);
      return saIn || (sa == null && eaIn);
    }).toList();

    list.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1; // 未完成在前
      final sa = a.startAt ?? DateTime(2100);
      final sb = b.startAt ?? DateTime(2100);
      return sa.compareTo(sb);
    });
    return list;
  }

  /// 兼容旧命名：某日期任务（未完成优先）
  List<Task> tasksForDay(DateTime day) => tasksForDate(day);

  /// 今日三件事（固定优先，不足补未完成）+ 应用拖拽序
  List<Task> top3ForDate(DateTime day) {
    final s = du.startOfDay(day);
    final e = du.endOfDay(day);

    final all = _taskBox.values.where((t) {
      final sa = t.startAt;
      final ea = t.endAt;
      final saIn = sa != null && !sa.isBefore(s) && !sa.isAfter(e);
      final eaIn = ea != null && !ea.isBefore(s) && !ea.isAfter(e);
      return saIn || (sa == null && eaIn);
    }).toList();

    final pinned = all.where((t) => t.isTodayTop3 && !t.done).toList();
    final rest = all.where((t) => !t.isTodayTop3 && !t.done).toList();
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

  /// 设定任务固定为「今日三件事」
  Future<void> setPinnedTop3(int taskKey, bool pinned) async {
    final t = _taskBox.get(taskKey);
    if (t == null) return;
    t.isTodayTop3 = pinned;
    await t.save();
    notifyListeners();
  }

  /// 拖拽后记录排序（底层是同步的，Adapter 外面会封一层 Future）
  void setTop3Order(DateTime day, List<int> orderedTaskKeys) {
    _top3OrderByDay[DateUtils.dateOnly(day)] = List.of(orderedTaskKeys);
    notifyListeners();
  }

  /// 基础：新增任务（带 Result 封装）
  Future<Result<int>> addTask(Task t) async {
    try {
      final key = await _taskBox.add(t);
      notifyListeners();
      return Success(key);
    } catch (e, s) {
      return Failure(Exception('addTask failed: $e'), s);
    }
  }

  /// 基础：更新任务
  Future<Result<void>> updateTask(int key, Task patch) async {
    try {
      final t = _taskBox.get(key);
      if (t == null) {
        return Failure(Exception('Task not found: $key'));
      }
      t
        ..title = patch.title
        ..note = patch.note
        ..goalId = patch.goalId
        ..subGoalId = patch.subGoalId
        ..startAt = patch.startAt
        ..endAt = patch.endAt
        ..done = patch.done
        ..isTodayTop3 = patch.isTodayTop3;
      await t.save();
      notifyListeners();
      return const Success(null);
    } catch (e, s) {
      return Failure(Exception('updateTask failed: $e'), s);
    }
  }

  /// 删除任务
  Future<Result<void>> deleteTask(int key) async {
    try {
      await _taskBox.delete(key);
      notifyListeners();
      return const Success(null);
    } catch (e, s) {
      return Failure(Exception('deleteTask failed: $e'), s);
    }
  }

  /// 新建今日任务（默认当天）
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

  /// 提供给 TaskAdapter.newTask() 使用的通用创建接口
  ///
  /// - [date] 为空时默认用今天
  /// - 返回 Hive 分配的 key
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

  /// 底层：显式设置完成状态（给 Adapter 用）
  Future<void> toggleTaskDone(int key, bool value) async {
    final t = _taskBox.get(key);
    if (t == null) return;
    t.done = value;
    await t.save();
    notifyListeners();
  }

  /// 兼容旧接口：切换完成状态（内部取反）
  Future<void> toggleDone(int key) async {
    final t = _taskBox.get(key);
    if (t == null) return;
    t.done = !t.done;
    await t.save();
    notifyListeners();
  }

  /// 导出为 JSON
  String exportAllToJson() {
    final list = _taskBox.keys.map((k) {
      final t = _taskBox.get(k as int)!;
      return {
        'key': k,
        'data': t.toMap(),
      };
    }).toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }

  /// 从 JSON 导入
  Future<Result<int>> importFromJson(String json) async {
    try {
      final decoded = jsonDecode(json) as List<dynamic>;
      int count = 0;
      for (final e in decoded) {
        final map = Map<String, dynamic>.from(e as Map);
        final key = map['key'] as int?;
        final t = Task.fromMap(
          Map<String, dynamic>.from(map['data'] as Map),
        );
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
}

