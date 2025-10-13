import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../core/hive_init.dart';
import '../models/task.dart';

class TaskProvider extends ChangeNotifier {
  late final Box<Task> _taskBox;

  Future<void> init() async {
    _taskBox = Hive.box<Task>(AppBoxes.task);
  }

  List<Task> tasksByGoal(int goalId) =>
      _taskBox.values.where((t) => t.goalId == goalId).toList();

  Future<int> addTask(Task t) async {
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

