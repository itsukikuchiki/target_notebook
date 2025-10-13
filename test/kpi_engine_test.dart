import 'package:test/test.dart';
import 'package:target_notebook/services/kpi_engine.dart';

void main() {
  group('normalizeProgress', () {
    test('zero or negative handled', () {
      expect(normalizeProgress(current: 0, target: 10), 0);
      expect(normalizeProgress(current: -5, target: 10), 0);
      expect(normalizeProgress(current: 5, target: 0), 0);
      expect(normalizeProgress(current: 5, target: -3), 0);
    });

    test('basic ratio and capped', () {
      expect(normalizeProgress(current: 5, target: 10), closeTo(0.5, 1e-9));
      expect(normalizeProgress(current: 15, target: 10), 1.0);
    });
  });
}

