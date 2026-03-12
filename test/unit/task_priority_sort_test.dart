// test/unit/task_priority_sort_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/providers/task_provider.dart';

import '../helpers/hive_test_env.dart';

void main() {
  setUpAll(() async {
    await HiveTestEnv.setUp();
  });

  setUp(() async {
    await clearHiveBoxes();
  });

  tearDownAll(() async {
    await HiveTestEnv.tearDown();
  });

  test('tasksForDate sorts: undone first, then priority asc, then deadline/startAt', () async {
    final box = Hive.box<Task>(AppBoxes.task);
    final p = TaskProvider();
    await p.init(taskBox: box);

    final day = DateTime(2026, 1, 10, 9);

    // priority 1 should come before priority 3 (ascending in your provider)
    final k1 = await box.add(Task(title: 'p3', startAt: day, priority: 3, done: false));
    final k2 = await box.add(Task(title: 'p1', startAt: day, priority: 1, done: false));

    // done should go last
    final k3 = await box.add(Task(title: 'done', startAt: day, priority: 0, done: true));

    // deadline tie-break
    final k4 = await box.add(Task(
      title: 'deadline earlier',
      startAt: day,
      priority: 1,
      deadline: DateTime(2026, 1, 10, 12),
      done: false,
    ));
    final k5 = await box.add(Task(
      title: 'deadline later',
      startAt: day,
      priority: 1,
      deadline: DateTime(2026, 1, 10, 13),
      done: false,
    ));

    final list = p.tasksForDate(day);

    // We only assert relative ordering by title to avoid Hive key ordering assumptions.
    final titles = list.map((e) => e.title).toList();

    // undone first
    expect(titles.last, 'done');

    // priority asc: p1 group should be before p3
    expect(titles.indexOf('p1') < titles.indexOf('p3'), true);

    // deadline earlier should be before later within same priority
    expect(titles.indexOf('deadline earlier') < titles.indexOf('deadline later'), true);

    // sanity: all exist
    expect({k1, k2, k3, k4, k5}.length, 5);
  });
}

