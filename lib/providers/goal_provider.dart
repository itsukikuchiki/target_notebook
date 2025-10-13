import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../core/hive_init.dart';
import '../core/result.dart';
import '../models/goal.dart';
import '../models/kpi.dart';
import '../models/daily_log.dart';
import '../services/kpi_engine.dart';

class GoalProvider extends ChangeNotifier {
  late final Box<Goal> _goalBox;
  late final Box<DailyLog> _logBox;

  Future<void> init() async {
    _goalBox = Hive.box<Goal>(AppBoxes.goal);
    _logBox = Hive.box<DailyLog>(AppBoxes.dailyLog);
  }

  List<Goal> get goals => _goalBox.values.toList()
    ..sort((a, b) => a.priority.compareTo(b.priority));

  // CRUD
  Future<Result<int>> addGoal(Goal g) async {
    try {
      final key = await _goalBox.add(g);
      notifyListeners();
      return Success(key);
    } catch (e, s) {
      return Failure(Exception('addGoal failed: $e'), s);
    }
  }

  Future<Result<void>> updateGoal(int key, Goal patch) async {
    try {
      final g = _goalBox.get(key);
      if (g == null) return Failure(Exception('Goal not found: $key'));
      g
        ..title = patch.title
        ..description = patch.description
        ..priority = patch.priority
        ..dueDate = patch.dueDate
        ..kpis = patch.kpis;
      await g.save();
      notifyListeners();
      return const Success(null);
    } catch (e, s) {
      return Failure(Exception('updateGoal failed: $e'), s);
    }
  }

  Future<Result<void>> deleteGoal(int key) async {
    try {
      await _goalBox.delete(key);
      notifyListeners();
      return const Success(null);
    } catch (e, s) {
      return Failure(Exception('deleteGoal failed: $e'), s);
    }
  }

  // KPI 刷新（由 DailyLog 触发或手动触发）
  Future<void> refreshKpisFor(int goalKey) async {
    final g = _goalBox.get(goalKey);
    if (g == null) return;
    final logs = _logBox.values.toList();
    final newKpis = refreshKpisForGoal(
      currentKpis: g.kpis,
      allLogs: logs,
      goalId: goalKey,
    );
    g.kpis = newKpis;
    await g.save();
    notifyListeners();
  }

  // === 批量导出：导出所有 Goal 为 JSON 字符串 ===
  String exportAllToJson() {
    final list = _goalBox.keys.map((k) {
      final g = _goalBox.get(k as int)!;
      return {'key': k, 'data': g.toMap()};
    }).toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }

  // === 批量导入：支持带 key/不带 key（不带 key 则追加） ===
  Future<Result<int>> importFromJson(String json) async {
    try {
      final decoded = jsonDecode(json) as List<dynamic>;
      int count = 0;
      for (final e in decoded) {
        final map = Map<String, dynamic>.from(e as Map);
        final key = map['key'] as int?;
        final g = Goal.fromMap(Map<String, dynamic>.from(map['data'] as Map));
        if (key != null) {
          await _goalBox.put(key, g);
        } else {
          await _goalBox.add(g);
        }
        count++;
      }
      notifyListeners();
      return Success(count);
    } catch (e, s) {
      return Failure(Exception('importFromJson failed: $e'), s);
    }
  }
}

