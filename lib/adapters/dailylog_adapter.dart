import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import '../providers/daily_log_provider.dart';
import '../models/daily_log.dart';

/// —— View Models ——
/// 与测试约定保持一致：外部常以 `import '.../dailylog_adapter.dart' as ui;` 引用。
class WeeklyStatsVM {
  /// 每天的投入小时数（key 为“去除时分秒”的日期）
  final Map<DateTime, double> hoursByDay;

  /// 完成率（0.0 ~ 1.0）。如果没有目标，则为 0.0。
  final double completionRate;

  /// 可选：用于 UI 的友好提示文案
  final String message;

  const WeeklyStatsVM(this.hoursByDay, this.completionRate, this.message);
}

/// 历史反思/随记（用于 `ReflectionPage`/Plus 面板等）
class ReflectionVM {
  final DateTime date;
  final String content;
  final int minutes;

  const ReflectionVM({
    required this.date,
    required this.content,
    required this.minutes,
  });
}

/// 为了兼容你历史上使用过的 `WeeklyVM` 命名，这里做一个别名
typedef WeeklyVM = WeeklyStatsVM;

/// —— Adapter ——
/// 包一层，隔离 Provider，提供 UI 直用的聚合/统计接口。
class DailyLogAdapter extends ChangeNotifier {
  final DailyLogProvider logs;

  DailyLogAdapter(this.logs) {
    // 监听底层 Provider 的变化并透传通知
    logs.addListener(_relay);
  }

  void _relay() => notifyListeners();

  @override
  void dispose() {
    logs.removeListener(_relay);
    super.dispose();
  }

  // ------------- 对外代理：新增快速日志（供 DailyPage/测试直接调用） -------------
  Future<int> addQuickLog({
    required DateTime date,
    required String content,
    required int minutes,
    int? taskId,
    int? goalId,
  }) {
    return logs.addQuickLog(
      date: date,
      content: content,
      minutes: minutes,
      taskId: taskId,
      goalId: goalId,
    );
  }

  // ------------- 聚合：周统计（供 InsightPage 使用） -------------
  /// 计算“当前周（周一~周日）”的投入小时分布与完成率。
  ///
  /// - `hoursByDay`：Map<DateOnly, hours>
  /// - `completionRate`：目前没有“目标阈值”数据，先简单按“本周是否有记录”给出 0 或 1。
  ///   如果你后续在 Goal/Setting 里提供“每周目标小时数”，这里可改为：`total / weeklyTargetHours`
  WeeklyStatsVM weeklyStats({DateTime? now}) {
    final anchor = now ?? DateTime.now();
    final start = _weekStart(anchor);
    final end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

    final all = logs.all();
    final inWeek = all.where((e) => !e.date.isBefore(start) && !e.date.isAfter(end)).toList();

    // 聚合：分钟 -> 小时
    final Map<DateTime, double> map = {};
    for (final e in inWeek) {
      final d = _dateOnly(e.date);
      final minutes = (map[d] ?? 0.0) + e.minutes.toDouble();
      map[d] = minutes;
    }
    // to hours
    map.updateAll((_, v) => v / 60.0);

    final totalHours = map.values.fold<double>(0.0, (a, b) => a + b);
    final hasAny = totalHours > 0.0;
    final completion = hasAny ? 1.0 : 0.0;

    final msg = hasAny
        ? '本周累计 ${totalHours.toStringAsFixed(1)} 小时'
        : '本周还没有记录投入时长，开始第一条吧！';

    return WeeklyStatsVM(map, completion, msg);
  }

  // ------------- 列表：最新反思/随记（供 ReflectionPage / PlusPanel 使用） -------------
  /// 取最近的 N 条日志，按时间倒序；这里只做一个最小可用实现（把所有 DailyLog 当作“反思”）
  List<ReflectionVM> latestReflections({int limit = 10}) {
    final all = logs.all()
      ..sort((a, b) => b.date.compareTo(a.date));
    return all.take(limit).map((e) {
      return ReflectionVM(date: e.date, content: e.content, minutes: e.minutes);
    }).toList();
  }

  // ------------- 工具方法 -------------
  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 以“周一”为每周起点
  static DateTime _weekStart(DateTime d) {
    final date = _dateOnly(d);
    final delta = (date.weekday + 6) % 7; // Mon=1 -> 0, Sun=7 -> 6
    return date.subtract(Duration(days: delta));
  }
}

