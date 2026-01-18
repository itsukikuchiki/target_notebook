import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../core/hive_init.dart'; // AppBoxes
import '../models/sub_goal.dart';
import '../utils/hive_initializer.dart'; // ensureTypedBox

class SubGoalProvider extends ChangeNotifier {
  late Box<SubGoal> _box;

  Future<void> init({
    Box<SubGoal>? box,
    String boxName = AppBoxes.subGoal,
  }) async {
    _box = box ?? await ensureTypedBox<SubGoal>(boxName);
  }

  /// 全量（一般不用直接渲染）
  List<SubGoal> get all => _box.values.toList();

  SubGoal? getByKey(int key) => _box.get(key);

  /// 核心：按 goalId 获取，并排序
  List<SubGoal> subGoalsByGoal(int goalId) {
    final list = _box.values.where((s) => s.goalId == goalId).toList();

    list.sort((a, b) {
      // 1) priority（小=高）
      final p = a.priority.compareTo(b.priority);
      if (p != 0) return p;

      // 2) orderIndex（显式顺序）
      final o = a.orderIndex.compareTo(b.orderIndex);
      if (o != 0) return o;

      // 3) title
      return a.title.compareTo(b.title);
    });

    return list;
  }

  Future<int> addSubGoal(SubGoal s) async {
    final key = await _box.add(s);
    notifyListeners();
    return key;
  }

  Future<void> updateSubGoal(int key, SubGoal patch) async {
    final s = _box.get(key);
    if (s == null) return;

    s
      ..goalId = patch.goalId
      ..title = patch.title
      ..description = patch.description
      ..orderIndex = patch.orderIndex
      ..priority = patch.priority
      ..color = patch.color;

    await s.save();
    notifyListeners();
  }

  Future<void> deleteSubGoal(int key) async {
    await _box.delete(key);
    notifyListeners();
  }
}


