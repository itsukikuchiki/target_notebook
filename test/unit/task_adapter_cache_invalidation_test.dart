// test/unit/task_adapter_cache_invalidation_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/providers/task_provider.dart';
import 'package:target_notebook/adapters/task_adapter.dart' as ui;

import '../helpers/hive_test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await HiveTestEnv.setUp();
  });

  setUp(() async {
    await clearHiveBoxes();
  });

  tearDownAll(() async {
    await HiveTestEnv.tearDown();
  });

  test('TaskAdapter updateTask: moving task to another day should not leave ghost in old day cache',
      () async {
    final taskBox = Hive.box<Task>(AppBoxes.task);

    final p = TaskProvider();
    await p.init(taskBox: taskBox);

    final a = ui.TaskAdapter(p);

    final dayA = DateTime(2026, 1, 10, 9, 0);
    final dayB = DateTime(2026, 1, 11, 9, 0);

    // 1) create on dayA via adapter (writes cache)
    final id = await a.newTask(title: 'MOVE-1', date: dayA);
    expect(a.tasksForDate(dayA).any((t) => t.id == id), true);

    // 2) move task to dayB via provider update
    final hiveTask = p.getByKey(id)!;
    hiveTask.startAt = dayB;
    hiveTask.endAt = dayB;
    await p.updateTask(hiveTask);

    // 3) adapter should not keep it in dayA list
    final listA = a.tasksForDate(dayA);
    final listB = a.tasksForDate(dayB);

    expect(listA.any((t) => t.id == id), false,
        reason: 'If this fails, TaskAdapter kept task in old date cache (ghost item).');
    expect(listB.any((t) => t.id == id), true);
  });

  test('TaskAdapter deleteTask: removes task from cached list', () async {
    final taskBox = Hive.box<Task>(AppBoxes.task);

    final p = TaskProvider();
    await p.init(taskBox: taskBox);

    final a = ui.TaskAdapter(p);

    final day = DateTime(2026, 1, 10, 9, 0);

    final id = await a.newTask(title: 'DEL-1', date: day);
    expect(a.tasksForDate(day).any((t) => t.id == id), true);

    await a.deleteTask(id);

    final list = a.tasksForDate(day);
    expect(list.any((t) => t.id == id), false);
  });
}
