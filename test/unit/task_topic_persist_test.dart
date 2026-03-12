import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/task.dart';
import '../helpers/hive_test_env.dart';
import '../hive_test_util.dart';

void main() {
  group('Task.topic', () {
    setUp(() async {
      await HiveTestEnv.setUp();
      await Hive.openBox<Task>(AppBoxes.task);
    });

    tearDown(() async {
      await HiveTestEnv.tearDown();
    });

    test('persists topic through Hive reboot (reopen box)', () async {
      final box = Hive.box<Task>(AppBoxes.task);

      final key = await box.add(
        Task(
          title: 'T1',
          topic: 'Work',
          note: 'n',
          priority: 2,
        ),
      );

      final saved = box.get(key)!;
      expect(saved.topic, 'Work');

      // reopen
      final reopened = await openTestBox<Task>(AppBoxes.task);
      final after = reopened.get(key)!;

      expect(after.title, 'T1');
      expect(after.topic, 'Work');
      expect(after.priority, 2);
    });

    test('toMap/fromMap includes topic', () {
      final t = Task(title: 'A', topic: 'Study', done: true, completion: 0.3);
      final m = t.toMap();
      expect(m['topic'], 'Study');

      final t2 = Task.fromMap(m);
      expect(t2.topic, 'Study');
      expect(t2.title, 'A');
      expect(t2.done, true);
    });
  });
}
