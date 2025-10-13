import 'package:test/test.dart';
import 'package:target_notebook/services/insight_service.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/models/daily_log.dart';

void main() {
  test('completionRatio basics', () {
    expect(InsightService.completionRatio([]), 0);
    expect(InsightService.completionRatio([Task(title: 'a'), Task(title: 'b', done: true)]), 0.5);
  });

  test('minutesForDay counts same-day logs', () {
    final d = DateTime(2025, 10, 20, 10);
    final logs = [
      DailyLog(date: d, content: 'a', minutes: 30),
      DailyLog(date: d.add(const Duration(hours: 1)), content: 'b', minutes: 15),
      DailyLog(date: d.add(const Duration(days: 1)), content: 'c', minutes: 999), // next day
    ];
    expect(InsightService.minutesForDay(logs, d), 45);
  });
}

