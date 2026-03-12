import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/sub_goal.dart';
import 'package:target_notebook/providers/sub_goal_provider.dart';

import '../helpers/hive_test_env.dart';
import '../helpers/hive_test_env.dart' show openTestBox;

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

  test('subGoalsByGoal filters by goalId and sorts by priority asc, orderIndex asc, title', () async {
    final box = Hive.box<SubGoal>(AppBoxes.subGoal);

    final p = SubGoalProvider();
    await p.init(box: box);

    // goalId 1
    final a = SubGoal(goalId: 1, title: 'C', priority: 2, orderIndex: 1);
    final b = SubGoal(goalId: 1, title: 'A', priority: 1, orderIndex: 5);
    final c = SubGoal(goalId: 1, title: 'B', priority: 1, orderIndex: 1);
    final d = SubGoal(goalId: 1, title: 'A2', priority: 1, orderIndex: 1);

    // goalId 2 (should not appear)
    final e = SubGoal(goalId: 2, title: 'X', priority: 1, orderIndex: 0);

    await box.addAll([a, b, c, d, e]);

    final list = p.subGoalsByGoal(1);
    final titles = list.map((x) => x.title).toList();

    // priority=1 first; within that orderIndex=1 first; within that title asc: A2, B, then orderIndex=5: A
    expect(titles, ['A2', 'B', 'A', 'C']);
  });

  test('add/update/delete persist', () async {
    final box = Hive.box<SubGoal>(AppBoxes.subGoal);
    final p = SubGoalProvider();
    await p.init(box: box);

    final key = await p.addSubGoal(SubGoal(goalId: 1, title: 'S', priority: 3));
    expect(p.getByKey(key)?.title, 'S');

    await p.updateSubGoal(
      key,
      SubGoal(goalId: 1, title: 'S2', description: 'D', orderIndex: 9, priority: 1, color: 0xFFABCDEF),
    );

    final updated = p.getByKey(key)!;
    expect(updated.title, 'S2');
    expect(updated.description, 'D');
    expect(updated.orderIndex, 9);
    expect(updated.priority, 1);
    expect(updated.color, 0xFFABCDEF);

    // 持久化验证：关闭 box 再打开
    await box.close();
    final reopened = await openTestBox<SubGoal>(AppBoxes.subGoal);
    final afterReopen = reopened.get(key)!;
    expect(afterReopen.title, 'S2');
    expect(afterReopen.color, 0xFFABCDEF);

    await p.init(box: reopened);
    await p.deleteSubGoal(key);
    expect(reopened.get(key), isNull);
  });
}

