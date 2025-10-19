import 'package:test/test.dart';
import 'package:target_notebook/services/insight_service.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/models/daily_log.dart';

void main() {
  group('InsightService.completionRatio', () {
    test('empty list returns 0', () {
      expect(InsightService.completionRatio(const []), equals(0.0));
    });

    test('basic ratio', () {
      final tasks = [
        Task(title: 'a'),
        Task(title: 'b', done: true),
      ];
      expect(InsightService.completionRatio(tasks), closeTo(0.5, 1e-9));
    });

    test('all done capped at 1.0', () {
      final tasks = [
        Task(title: 'a', done: true),
        Task(title: 'b', done: true),
      ];
      expect(InsightService.completionRatio(tasks), closeTo(1.0, 1e-9));
    });
  });

  group('InsightService.minutesForDay', () {
    test('counts same-day logs only', () {
      final d = DateTime(2025, 10, 20, 10);
      final logs = [
        DailyLog(date: d, content: 'a', minutes: 30),
        DailyLog(date: d.add(const Duration(hours: 1)), content: 'b', minutes: 15),
        DailyLog(date: d.add(const Duration(days: 1)), content: 'c', minutes: 999), // next day
      ];
      expect(InsightService.minutesForDay(logs, d), equals(45));
    });

    test('excludes previous and next day', () {
      final day = DateTime(2025, 10, 20, 12, 0, 0);
      final prev = DateTime(2025, 10, 19, 23, 59, 59);
      final next = DateTime(2025, 10, 21, 0, 0, 1);

      final logs = [
        DailyLog(date: prev, content: 'prev-day', minutes: 50),
        DailyLog(date: day.add(const Duration(minutes: 5)), content: 'same-day-1', minutes: 20),
        DailyLog(date: day.subtract(const Duration(hours: 1)), content: 'same-day-2', minutes: 10),
        DailyLog(date: next, content: 'next-day', minutes: 80),
      ];

      expect(InsightService.minutesForDay(logs, day), equals(30));
    });
  });
}

