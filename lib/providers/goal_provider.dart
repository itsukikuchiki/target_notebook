import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../core/hive_init.dart';
import '../models/goal.dart';

class GoalProvider extends ChangeNotifier {
  late final Box<Goal> _goalBox;

  Future<void> init() async {
    _goalBox = Hive.box<Goal>(AppBoxes.goal);
  }

  List<Goal> get goals => _goalBox.values.toList()
    ..sort((a, b) => a.priority.compareTo(b.priority));

  Future<int> addGoal(Goal g) async {
    final key = await _goalBox.add(g);
    notifyListeners();
    return key;
  }

  Future<void> deleteGoal(int key) async {
    await _goalBox.delete(key);
    notifyListeners();
  }
}

