import 'package:flutter_test/flutter_test.dart';
import 'package:target_notebook/pages/daily_page.dart';

void main() {
  test('dailyDateKey formats as YYYY-MM-DD', () {
    expect(dailyDateKey(DateTime(2026, 2, 3)), '2026-02-03');
    expect(dailyDateKey(DateTime(2000, 1, 1)), '2000-01-01');
    expect(dailyDateKey(DateTime(2100, 12, 31)), '2100-12-31');
  });

  test('dailyDateOnly strips time', () {
    final d = dailyDateOnly(DateTime(2026, 2, 3, 12, 34, 56));
    expect(d, DateTime(2026, 2, 3));
  });

  test('dailyIsSameDay compares date only', () {
    expect(dailyIsSameDay(DateTime(2026, 2, 3, 1), DateTime(2026, 2, 3, 23)), true);
    expect(dailyIsSameDay(DateTime(2026, 2, 3), DateTime(2026, 2, 4)), false);
  });
}
