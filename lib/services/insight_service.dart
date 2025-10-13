import '../models/task.dart';
import '../models/daily_log.dart';

class InsightService {
  /// 完成率：done / total（若 total=0 返回 0）
  static double completionRatio(List<Task> tasks) {
    if (tasks.isEmpty) return 0.0;
    final done = tasks.where((t) => t.done).length;
    return done / tasks.length;
  }

  /// 当天投入分钟总和
  static int minutesForDay(List<DailyLog> logs, DateTime day) {
    final s = DateTime(day.year, day.month, day.day);
    final e = s.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    return logs.where((l) => !l.date.isBefore(s) && !l.date.isAfter(e)).fold(0, (a, b) => a + b.minutes);
  }
}

