import '../models/kpi.dart';
import '../models/daily_log.dart';

/// 归一化进度：返回 0..1 之间（溢出封顶），负值按 0 处理
double normalizeProgress({required double current, required double target}) {
  if (target <= 0) return 0.0;
  if (current <= 0) return 0.0;
  final p = current / target;
  return p.isNaN || p.isInfinite ? 0.0 : (p > 1.0 ? 1.0 : p);
}

/// 计算“本周分钟数”是否适用于 KPI（举例：period == 'weekly'）
int _minutesOfWeek(List<DailyLog> logs, DateTime day, {int? goalId}) {
  // 以本地周一为一周起点
  final weekday = day.weekday; // 1..7
  final start = DateTime(day.year, day.month, day.day).subtract(Duration(days: weekday - 1));
  final end = start.add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1));
  int sum = 0;
  for (final l in logs) {
    if (goalId != null && l.goalId != goalId) continue;
    final d = l.date;
    if (!d.isBefore(start) && !d.isAfter(end)) {
      sum += l.minutes;
    }
  }
  return sum;
}

/// 根据日志刷新指定 Goal 的 KPI 列表（纯函数：返回新的 KPI 列表，不修改入参）
List<KPI> refreshKpisForGoal({
  required List<KPI> currentKpis,
  required List<DailyLog> allLogs,
  required int goalId,
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  return currentKpis.map((k) {
    if (k.period == 'weekly') {
      final minutes = _minutesOfWeek(allLogs, n, goalId: goalId);
      final hours = minutes / 60.0;
      return KPI(
        name: k.name,
        targetValue: k.targetValue,
        currentValue: hours, // 用小时体现
        unit: k.unit,
        period: k.period,
      );
    }
    // 其它周期后续扩展：daily / monthly / quarterly...
    return k;
  }).toList();
}

