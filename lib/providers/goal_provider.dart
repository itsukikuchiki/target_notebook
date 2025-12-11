import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../core/hive_init.dart';
import '../models/goal.dart';
import '../models/daily_log.dart';
import '../utils/hive_initializer.dart';

class GoalProvider extends ChangeNotifier {
  late Box<Goal> _goalBox;
  late Box<DailyLog> _logBox;

  /// 可注入两个 Box；默认使用 AppBoxes
  Future<void> init({
    Box<Goal>? goalBox,
    Box<DailyLog>? logBox,
    String goalBoxName = AppBoxes.goal,
    String logBoxName = AppBoxes.dailyLog,
  }) async {
    _goalBox = goalBox ?? await ensureTypedBox<Goal>(goalBoxName);
    _logBox = logBox ?? await ensureTypedBox<DailyLog>(logBoxName);
  }

  /// 全量 Goal
  List<Goal> get goals => _goalBox.values.toList();

  /// 新增
  Future<int> addGoal(Goal g) async {
    final key = await _goalBox.add(g);
    notifyListeners();
    return key;
  }

  /// 更新（按照当前 Goal 模型字段进行 patch）
  Future<void> updateGoal(int key, Goal patch) async {
    final g = _goalBox.get(key);
    if (g == null) return;

    g
      ..title = patch.title
      ..description = patch.description
      ..priority = patch.priority
      ..dueDate = patch.dueDate
      ..kpis = patch.kpis;

    await g.save();
    notifyListeners();
  }

  /// 删除
  Future<void> deleteGoal(int key) async {
    await _goalBox.delete(key);
    notifyListeners();
  }

  Goal? getByKey(int key) => _goalBox.get(key);

  /// —— 可选：导出 / 导入（便于备份）——
  String exportAllToJson() {
    final list = _goalBox.keys.map((k) {
      final g = _goalBox.get(k as int)!;
      return {
        'key': k,
        'data': g.toMap(),
      };
    }).toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }

  Future<int> importFromJson(String json) async {
    final decoded = jsonDecode(json) as List<dynamic>;
    int count = 0;
    for (final e in decoded) {
      final map = Map<String, dynamic>.from(e as Map);
      final key = map['key'] as int?;
      final g = Goal.fromMap(
        Map<String, dynamic>.from(map['data'] as Map),
      );
      if (key != null) {
        await _goalBox.put(key, g);
      } else {
        await _goalBox.add(g);
      }
      count++;
    }
    notifyListeners();
    return count;
  }

  /// —— 如果后续需要从日志计算 KPI，可在此读取 _logBox.values 做聚合 —— ///
  List<DailyLog> allLogs() => _logBox.values.toList();
}

