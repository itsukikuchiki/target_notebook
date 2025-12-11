import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../core/hive_init.dart';
import '../models/daily_log.dart';
import '../models/goal.dart';
import '../models/kpi.dart';
import '../utils/hive_initializer.dart';

class DailyLogProvider extends ChangeNotifier {
  late Box<DailyLog> _logBox;

  /// 可注入 [logBox]；默认打开 [AppBoxes.dailyLog]
  Future<void> init({
    Box<DailyLog>? logBox,
    String boxName = AppBoxes.dailyLog,
  }) async {
    _logBox = logBox ?? await ensureTypedBox<DailyLog>(boxName);
  }

  /// 全量（Adapter/Insight 会直接读取）
  List<DailyLog> all() => _logBox.values.toList();

  /// 新增一条快速日志（供 UI / Adapter 使用）
  Future<int> addQuickLog({
    required DateTime date,
    required String content,
    required int minutes,
    int? taskId,
    int? goalId,
  }) async {
    final log = DailyLog(
      date: date,
      content: content,
      minutes: minutes,
      taskId: taskId,
      goalId: goalId,
    );
    final k = await _logBox.add(log);
    await _updateWeeklyKpiForGoal(goalId, date);
    notifyListeners();
    return k;
  }

  /// 兼容旧接口：addLog（供早期测试使用）
  ///
  /// 行为等价于 addQuickLog，只是命名不同。
  Future<int> addLog(DailyLog log) async {
    final k = await _logBox.add(log);
    await _updateWeeklyKpiForGoal(log.goalId, log.date);
    notifyListeners();
    return k;
  }

  /// 删除
  Future<void> delete(int key) async {
    final old = _logBox.get(key);
    await _logBox.delete(key);
    if (old != null) {
      await _updateWeeklyKpiForGoal(old.goalId, old.date);
    }
    notifyListeners();
  }

  /// 更新
  Future<void> update(int key, DailyLog patch) async {
    final l = _logBox.get(key);
    if (l == null) return;
    l
      ..date = patch.date
      ..content = patch.content
      ..minutes = patch.minutes
      ..taskId = patch.taskId
      ..goalId = patch.goalId;
    await l.save();
    await _updateWeeklyKpiForGoal(l.goalId, l.date);
    notifyListeners();
  }

  // ------------------ KPI 刷新逻辑：每周学习时长 ------------------

  Future<void> _updateWeeklyKpiForGoal(int? goalId, DateTime date) async {
    if (goalId == null) return;

    // 1) 取对应 Goal
    final goalBox = await ensureTypedBox<Goal>(AppBoxes.goal);
    final goal = goalBox.get(goalId);
    if (goal == null) return;

    // 2) 计算该周范围（周一 ~ 下周一不含）
    final weekStart = _weekStart(date);
    final weekEnd = weekStart.add(const Duration(days: 7));

    // 3) 聚合这一周该 Goal 的所有日志分钟数
    final logs = _logBox.values.where((l) {
      if (l.goalId != goalId) return false;
      final d = l.date;
      return !d.isBefore(weekStart) && d.isBefore(weekEnd);
    });

    final totalMinutes =
        logs.fold<int>(0, (sum, l) => sum + (l.minutes));
    final hours = totalMinutes / 60.0;

    // 4) 更新所有 weekly KPI 的 currentValue
    final updated = <KPI>[];
    for (final kpi in goal.kpis) {
      if (kpi.period == 'weekly') {
        updated.add(
          KPI(
            name: kpi.name,
            targetValue: kpi.targetValue,
            currentValue: hours,
            unit: kpi.unit,
            period: kpi.period,
          ),
        );
      } else {
        updated.add(kpi);
      }
    }
    goal.kpis = updated;
    await goal.save();
  }

  static DateTime _dateOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  /// 以“周一”为每周起点
  static DateTime _weekStart(DateTime d) {
    final date = _dateOnly(d);
    final delta = (date.weekday + 6) % 7; // Mon=1 -> 0, Sun=7 -> 6
    return date.subtract(Duration(days: delta));
  }
}

