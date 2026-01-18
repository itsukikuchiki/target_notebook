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

  /// 全量 Goal（原样，不排序，保留兼容）
  List<Goal> get goals => _goalBox.values.toList();

  /// 新增：按 priority 排序后的 goals（priority 小在前）
  List<Goal> get goalsSorted {
    final list = goals;
    list.sort((a, b) {
      final p = a.priority.compareTo(b.priority);
      if (p != 0) return p;
      // secondary: createdAt（早的在前）
      final c = a.createdAt.compareTo(b.createdAt);
      if (c != 0) return c;
      return a.title.compareTo(b.title);
    });
    return list;
  }

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
      ..kpis = patch.kpis
      ..color = patch.color; // ✅ W5: 颜色字段别漏了

    await g.save();
    notifyListeners();
  }

  /// 新增：仅更新颜色（给颜色选择器用）
  Future<void> setGoalColor(int key, int? color) async {
    final g = _goalBox.get(key);
    if (g == null) return;
    g.color = color;
    await g.save();
    notifyListeners();
  }

  /// 删除
  Future<void> deleteGoal(int key) async {
    await _goalBox.delete(key);
    notifyListeners();
  }

  Goal? getByKey(int key) => _goalBox.get(key);

  // =========================================================
  // Color helpers (12/15)
  // =========================================================

  /// 返回“有效颜色”（若未设置则返回默认色）
  /// 默认色使用一组稳定的颜色表 + key/seed 取模，保证同一个 goal 每次显示一致
  int effectiveColorInt(Goal g, {int? goalKey, int seed = 0}) {
    if (g.color != null) return g.color!;

    // 这里用 Material 常见色（ARGB），不依赖 Theme，稳定且可用
    const defaults = <int>[
      0xFFEF5350, // red
      0xFFAB47BC, // purple
      0xFF5C6BC0, // indigo
      0xFF29B6F6, // lightBlue
      0xFF26A69A, // teal
      0xFF66BB6A, // green
      0xFFFFCA28, // amber
      0xFFFFA726, // orange
      0xFF8D6E63, // brown
      0xFF78909C, // blueGrey
    ];

    // goalKey 优先（更稳定），否则用 title hash
    final base = (goalKey ?? g.title.hashCode) + seed;
    final idx = base.abs() % defaults.length;
    return defaults[idx];
  }

  // =========================================================
  // Import / Export
  // =========================================================

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

