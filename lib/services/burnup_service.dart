// lib/services/burnup_service.dart

import '../models/task.dart';

/// 单个时间点（用于 Burnup / Burndown）
class BurnPoint {
  final DateTime date; // dateOnly
  final int value;     // 累计完成数 or 剩余数

  const BurnPoint({
    required this.date,
    required this.value,
  });
}

/// Burnup / Burndown 计算服务（纯函数，无状态）
class BurnupService {
  BurnupService._();

  /// =========================
  /// Burnup：已完成任务累计数
  /// =========================
  static List<BurnPoint> buildBurnup({
    required List<Task> tasks,
  }) {
    // 1️⃣ 取所有已完成任务，并提取日期
    final completedDates = <DateTime>[];

    for (final t in tasks) {
      if (!t.done) continue;
      final d = t.startAt ?? t.deadline;
      if (d == null) continue;
      completedDates.add(_dateOnly(d));
    }

    if (completedDates.isEmpty) return const [];

    // 2️⃣ 按日期排序
    completedDates.sort();

    // 3️⃣ 按天累计
    final Map<DateTime, int> countByDay = {};
    for (final d in completedDates) {
      countByDay[d] = (countByDay[d] ?? 0) + 1;
    }

    final days = countByDay.keys.toList()..sort();

    int acc = 0;
    final points = <BurnPoint>[];

    for (final d in days) {
      acc += countByDay[d]!;
      points.add(BurnPoint(date: d, value: acc));
    }

    return points;
  }

  /// =========================
  /// Burndown：剩余任务数
  /// =========================
  static List<BurnPoint> buildBurndown({
    required List<Task> tasks,
  }) {
    final total = tasks.length;
    if (total == 0) return const [];

    // 完成日期
    final completedDates = <DateTime>[];

    for (final t in tasks) {
      if (!t.done) continue;
      final d = t.startAt ?? t.deadline;
      if (d == null) continue;
      completedDates.add(_dateOnly(d));
    }

    if (completedDates.isEmpty) {
      // 从今天开始，全量未完成
      final today = _dateOnly(DateTime.now());
      return [
        BurnPoint(date: today, value: total),
      ];
    }

    completedDates.sort();

    final Map<DateTime, int> doneByDay = {};
    for (final d in completedDates) {
      doneByDay[d] = (doneByDay[d] ?? 0) + 1;
    }

    final days = doneByDay.keys.toList()..sort();

    int remaining = total;
    final points = <BurnPoint>[];

    for (final d in days) {
      remaining -= doneByDay[d]!;
      remaining = remaining < 0 ? 0 : remaining;
      points.add(BurnPoint(date: d, value: remaining));
    }

    return points;
  }

  // =========================
  // Utils
  // =========================

  static DateTime _dateOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day);
}

