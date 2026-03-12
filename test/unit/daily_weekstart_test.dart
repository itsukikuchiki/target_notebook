import 'package:flutter_test/flutter_test.dart';
import 'package:target_notebook/pages/daily_page.dart';
import 'package:target_notebook/providers/settings_provider.dart';

void main() {
  group('dailyVisibleDaysForWeekStrip', () {
    test('WeekStart.monday -> week starts on Monday', () {
      // 2026-02-01 is Sunday
      final selected = DateTime(2026, 2, 1);

      final days = dailyVisibleDaysForWeekStrip(selected, WeekStart.monday);

      expect(days.length, 7);
      // Monday start => first day should be 2026-01-26 (Mon)
      expect(days.first, DateTime(2026, 1, 26));
      expect(days.last, DateTime(2026, 2, 1));
      expect(days.first.weekday, DateTime.monday);
    });

    test('WeekStart.sunday -> week starts on Sunday', () {
      // 2026-02-01 is Sunday
      final selected = DateTime(2026, 2, 1);

      final days = dailyVisibleDaysForWeekStrip(selected, WeekStart.sunday);

      expect(days.length, 7);
      // Sunday start => first day should be itself
      expect(days.first, DateTime(2026, 2, 1));
      expect(days.first.weekday, DateTime.sunday);
      expect(days.last, DateTime(2026, 2, 7));
    });
  });
}
