import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../core/hive_init.dart';
import '../core/result.dart';
import '../models/daily_log.dart';
import '../models/goal.dart';
import '../services/kpi_engine.dart';

class DailyLogProvider extends ChangeNotifier {
  late final Box<DailyLog> _logBox;
  late final Box<Goal> _goalBox;

  Future<void> init() async {
    _logBox = Hive.box<DailyLog>(AppBoxes.dailyLog);
    _goalBox = Hive.box<Goal>(AppBoxes.goal);
  }

  List<DailyLog> logsForDay(DateTime day) {
    final s = DateTime(day.year, day.month, day.day);
    final e = s.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    return _logBox.values.where((l) => !l.date.isBefore(s) && !l.date.isAfter(e)).toList();
  }

  // 写日志后 -> 刷新对应 Goal 的 KPI
  Future<Result<int>> addLog(DailyLog l) async {
    try {
      final key = await _logBox.add(l);

      if (l.goalId != null) {
        final g = _goalBox.get(l.goalId);
        if (g != null) {
          // 关键：用“日志的日期”作为参考周，这样测试与实际都可复现
          final newKpis = refreshKpisForGoal(
            currentKpis: g.kpis,
            allLogs: _logBox.values.toList(),
            goalId: l.goalId!,
            now: l.date, // ← 新增
          );
          g.kpis = newKpis;
          await g.save();
        }
      }

      notifyListeners();
      return Success(key);
    } catch (e, s) {
      return Failure(Exception('addLog failed: $e'), s);
    }
  }

  Future<Result<void>> deleteLog(int key) async {
    try {
      await _logBox.delete(key);
      notifyListeners();
      return const Success(null);
    } catch (e, s) {
      return Failure(Exception('deleteLog failed: $e'), s);
    }
  }

  String exportAllToJson() {
    final list = _logBox.keys.map((k) {
      final l = _logBox.get(k as int)!;
      return {'key': k, 'data': l.toMap()};
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
        final l = DailyLog.fromMap(Map<String, dynamic>.from(map['data'] as Map));
        if (key != null) {
          await _logBox.put(key, l);
        } else {
          await _logBox.add(l);
        }
        count++;
      }
      notifyListeners();
      return Success(count);
    } catch (e, s) {
      return Failure(Exception('import logs failed: $e'), s);
    }
  }
}

