import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../core/hive_init.dart';
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

  Future<int> addTask(Task t) async {
    final key = await _taskBox.add(t);
    notifyListeners();
    return key;
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
}

