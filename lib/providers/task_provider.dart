import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../core/hive_init.dart';
import '../core/result.dart';
import '../models/task.dart';
import '../common/utils/date_utils.dart';

class TaskProvider extends ChangeNotifier {
  late final Box<Task> _taskBox;

  Future<void> init() async {
    _taskBox = Hive.box<Task>(AppBoxes.task);
  }

  List<Task> tasksByGoal(int goalId) =>
      _taskBox.values.where((t) => t.goalId == goalId).toList();

  List<Task> tasksForDay(DateTime day) {
    final s = startOfDay(day);
    final e = endOfDay(day);
    final list = _taskBox.values.where((t) {
      final sa = t.startAt;
      final ea = t.endAt;
      final saIn = sa != null && !sa.isBefore(s) && !sa.isAfter(e);
      final eaIn = ea != null && !ea.isBefore(s) && !ea.isAfter(e);
      return saIn || (sa == null && eaIn);
    }).toList();
    list.sort((a, b) => (a.done ? 1 : 0).compareTo(b.done ? 1 : 0));
    return list;
  }

  // CRUD
  Future<Result<int>> addTask(Task t) async {
    try {
      final key = await _taskBox.add(t);
      notifyListeners();
      return Success(key);
    } catch (e, s) {
      return Failure(Exception('addTask failed: $e'), s);
    }
  }

  Future<Result<void>> updateTask(int key, Task patch) async {
    try {
      final t = _taskBox.get(key);
      if (t == null) return Failure(Exception('Task not found: $key'));
      t
        ..title = patch.title
        ..note = patch.note
        ..goalId = patch.goalId
        ..subGoalId = patch.subGoalId
        ..startAt = patch.startAt
        ..endAt = patch.endAt
        ..done = patch.done;
      await t.save();
      notifyListeners();
      return const Success(null);
    } catch (e, s) {
      return Failure(Exception('updateTask failed: $e'), s);
    }
  }

  Future<Result<void>> deleteTask(int key) async {
    try {
      await _taskBox.delete(key);
      notifyListeners();
      return const Success(null);
    } catch (e, s) {
      return Failure(Exception('deleteTask failed: $e'), s);
    }
  }

  Future<int> addQuickTaskToday(String title) async {
    final now = DateTime.now();
    final t = Task(title: title.trim().isEmpty ? '今日任务' : title.trim(), startAt: now);
    final key = await _taskBox.add(t);
    notifyListeners();
    return key;
  }

  Future<void> toggleDone(int key) async {
    final t = _taskBox.get(key);
    if (t == null) return;
    t.done = !t.done;
    await t.save();
    notifyListeners();
  }

  // 批量导出/导入
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
}

