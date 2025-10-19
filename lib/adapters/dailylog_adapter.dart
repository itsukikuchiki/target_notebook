import 'package:flutter/foundation.dart';
import '../providers/daily_log_provider.dart' as phase1; // ✅ 正确文件名：daily_log_provider.dart
import '../providers/task_provider.dart' as phase1;

class WeeklyStatsVM {
  final Map<DateTime, double> hoursByDay; // 7 天
  final double completionRate;            // 0..1
  final String summary;
  const WeeklyStatsVM(this.hoursByDay, this.completionRate, this.summary);
}

class ReflectionVM {
  final DateTime date;
  final String content;
  const ReflectionVM(this.date, this.content);
}

class DailyLogAdapter extends ChangeNotifier {
  final phase1.DailyLogProvider logs;
  final phase1.TaskProvider tasks;
  DailyLogAdapter(this.logs, this.tasks) {
    logs.addListener(notifyListeners);
    tasks.addListener(notifyListeners);
  }

  // ===== Insight：最近 7 天投入时长 + 完成率 =====
  WeeklyStatsVM weeklyStats() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final Map<DateTime, double> hours = {};

    for (int i = 0; i < 7; i++) {
      final d = DateTime(start.year, start.month, start.day + i);
      final list = logs.logsForDay(d);
      final totalH = list.fold<double>(0, (sum, e) => sum + (e.minutes / 60.0));
      hours[DateTime(d.year, d.month, d.day)] = totalH;
    }

    int done = 0, total = 0;
    for (int i = 0; i < 7; i++) {
      final d = DateTime(start.year, start.month, start.day + i);
      final ts = tasks.tasksForDay(d);
      total += ts.length;
      done  += ts.where((t) => t.done).length;
    }
    final rate = total == 0 ? 0.0 : (done / total).clamp(0, 1).toDouble();

    final totalHours = hours.values.fold<double>(0, (a, b) => a + b);
    final summary = totalHours == 0
        ? '本周还没有记录投入时长，开始第一条吧！'
        : '本周累计 ${totalHours.toStringAsFixed(1)} 小时，完成率 ${(rate * 100).toStringAsFixed(0)}%。';

    return WeeklyStatsVM(hours, rate, summary);
  }

  // ===== Reflection：最近 10 条（取 DailyLog.content 非空）=====
  List<ReflectionVM> latestReflections() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final List<ReflectionVM> out = [];

    for (int i = 0; i < 30; i++) {
      final d = DateTime(start.year, start.month, start.day - i);
      final list = logs.logsForDay(d);
      for (final l in list) {
        final text = l.content.trim();
        if (text.isNotEmpty) {
          out.add(ReflectionVM(l.date, text));
        }
      }
      if (out.length >= 10) break;
    }

    out.sort((a, b) => b.date.compareTo(a.date));
    return out.take(10).toList();
  }
}

