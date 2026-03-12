import 'package:flutter_test/flutter_test.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/services/burnup_service.dart';

void main() {
  group('BurnupService', () {
    test('buildBurnup accumulates completed tasks by day (dateOnly, skips undated done)', () {
      final d1 = DateTime(2026, 1, 1, 10, 30);
      final d2 = DateTime(2026, 1, 2, 9, 0);
      final d3 = DateTime(2026, 1, 3, 18, 10);

      final tasks = <Task>[
        // Day1: done x1
        _t(title: 'A', done: true, startAt: d1),

        // Day2: not done -> ignored for burnup
        _t(title: 'B', done: false, startAt: d2),

        // Day3: done x2
        _t(title: 'C', done: true, startAt: d3),
        _t(title: 'D', done: true, deadline: d3), // uses deadline if startAt null

        // done but no startAt/deadline -> ignored
        _t(title: 'E', done: true),
      ];

      final points = BurnupService.buildBurnup(tasks: tasks);

      // buildBurnup 只对“有完成事件的日期”出点，不会补齐空日
      expect(points.map((p) => _ymd(p.date)).toList(), equals([
        '2026-01-01',
        '2026-01-03',
      ]));

      // Day1 = 1
      // Day3 = 1 + 2 = 3
      expect(points.map((p) => p.value).toList(), equals([1, 3]));
    });

    test('buildBurndown returns remaining tasks on each completion day', () {
      final d1 = DateTime(2026, 1, 1, 10, 30);
      final d3 = DateTime(2026, 1, 3, 18, 10);

      // total = 4
      // completed:
      //  - Day1: 1 -> remaining 3
      //  - Day3: 2 -> remaining 1
      final tasks = <Task>[
        _t(title: 'A', done: true, startAt: d1),
        _t(title: 'B', done: false),
        _t(title: 'C', done: true, startAt: d3),
        _t(title: 'D', done: true, deadline: d3),
      ];

      final points = BurnupService.buildBurndown(tasks: tasks);

      expect(points.map((p) => _ymd(p.date)).toList(), equals([
        '2026-01-01',
        '2026-01-03',
      ]));

      expect(points.map((p) => p.value).toList(), equals([
        3, // after Day1 done 1
        1, // after Day3 done 2 more
      ]));
    });

    test('buildBurnup returns empty list when no completed tasks exist', () {
      final tasks = <Task>[
        _t(title: 'A', done: false, startAt: DateTime(2026, 1, 1)),
        _t(title: 'B', done: false),
      ];

      expect(BurnupService.buildBurnup(tasks: tasks), isEmpty);
    });

    test('buildBurndown returns empty list when tasks is empty', () {
      expect(BurnupService.buildBurndown(tasks: const <Task>[]), isEmpty);
    });

    test('buildBurndown when no completed tasks returns [today -> total]', () {
      final tasks = <Task>[
        _t(title: 'A', done: false),
        _t(title: 'B', done: false),
        _t(title: 'C', done: false),
      ];

      final points = BurnupService.buildBurndown(tasks: tasks);

      expect(points.length, 1);
      expect(points.single.value, 3);

      // 与实现一致：_dateOnly(DateTime.now())
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      expect(_ymd(points.single.date), _ymd(today));
    });
  });
}

Task _t({
  required String title,
  required bool done,
  DateTime? startAt,
  DateTime? deadline,
}) {
  return Task(
    title: title,
    done: done,
    startAt: startAt,
    deadline: deadline,
  );
}

/// YYYY-MM-DD，避免时区/时分秒导致 flaky
String _ymd(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

