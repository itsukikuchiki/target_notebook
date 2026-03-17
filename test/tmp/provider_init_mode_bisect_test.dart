import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/goal.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/providers/goal_provider.dart';
import 'package:target_notebook/providers/sub_goal_provider.dart';
import 'package:target_notebook/providers/task_provider.dart';

import '../helpers/hive_test_env.dart';
import '../fakes/fake_notification_local_service.dart';

void main() {
  test('TEST P1: plain test provider/data-only flow', () async {
    print('STEP P1-1: before HiveTestEnv.setUp');
    await HiveTestEnv.setUp();
    print('STEP P1-2: after HiveTestEnv.setUp');

    print('STEP P1-3: before clearHiveBoxes');
    await clearHiveBoxes();
    print('STEP P1-4: after clearHiveBoxes');

    print('STEP P1-5: before Hive.box goal/task');
    final goalBox = Hive.box<Goal>(AppBoxes.goal);
    final taskBox = Hive.box<Task>(AppBoxes.task);
    print('STEP P1-6: after Hive.box goal/task');

    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day, 9);

    print('STEP P1-7: before goalBox.add');
    final goalKey = await goalBox.add(Goal(title: 'G-Red', priority: 1, color: 0xFFFF0000));
    print('STEP P1-8: after goalBox.add goalKey=$goalKey');

    print('STEP P1-9: before taskBox.add GoalTask');
    await taskBox.add(Task(title: 'GoalTask', goalId: goalKey, startAt: day, endAt: day, color: null));
    print('STEP P1-10: after taskBox.add GoalTask');

    print('STEP P1-11: before taskBox.add ScheduleTask');
    await taskBox.add(Task(title: 'ScheduleTask', goalId: null, startAt: day, endAt: day, color: 0xFF0000FF));
    print('STEP P1-12: after taskBox.add ScheduleTask');

    print('STEP P1-13: before GoalProvider.init(goalBox: goalBox)');
    final goalP = GoalProvider();
    await goalP.init(goalBox: goalBox);
    print('STEP P1-14: after GoalProvider.init(goalBox: goalBox)');

    print('STEP P1-15: before SubGoalProvider.init()');
    final subP = SubGoalProvider();
    await subP.init();
    print('STEP P1-16: after SubGoalProvider.init()');

    print('STEP P1-17: before TaskProvider.init(taskBox: taskBox, notification: FakeNotificationLocalService())');
    final taskP = TaskProvider();
    await taskP.init(taskBox: taskBox, notification: FakeNotificationLocalService());
    print('STEP P1-18: after TaskProvider.init(taskBox: taskBox, notification: FakeNotificationLocalService())');

    print('STEP P1-19: before HiveTestEnv.tearDown');
    await HiveTestEnv.tearDown();
    print('STEP P1-20: after HiveTestEnv.tearDown');
  });

  testWidgets('TEST P2: testWidgets same provider/data-only flow', (tester) async {
    print('STEP P2-1: before HiveTestEnv.setUp');
    await HiveTestEnv.setUp();
    print('STEP P2-2: after HiveTestEnv.setUp');

    print('STEP P2-3: before clearHiveBoxes');
    await clearHiveBoxes();
    print('STEP P2-4: after clearHiveBoxes');

    print('STEP P2-5: before Hive.box goal/task');
    final goalBox = Hive.box<Goal>(AppBoxes.goal);
    final taskBox = Hive.box<Task>(AppBoxes.task);
    print('STEP P2-6: after Hive.box goal/task');

    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day, 9);

    print('STEP P2-7: before goalBox.add');
    final goalKey = await tester.runAsync(() async {
      return goalBox.add(Goal(title: 'G-Red', priority: 1, color: 0xFFFF0000));
    });
    print('STEP P2-8: after goalBox.add goalKey=$goalKey');

    print('STEP P2-9: before taskBox.add GoalTask');
    await tester.runAsync(() async {
      await taskBox.add(Task(title: 'GoalTask', goalId: goalKey, startAt: day, endAt: day, color: null));
    });
    print('STEP P2-10: after taskBox.add GoalTask');

    print('STEP P2-11: before taskBox.add ScheduleTask');
    await tester.runAsync(() async {
      await taskBox.add(Task(title: 'ScheduleTask', goalId: null, startAt: day, endAt: day, color: 0xFF0000FF));
    });
    print('STEP P2-12: after taskBox.add ScheduleTask');

    print('STEP P2-13: before GoalProvider.init(goalBox: goalBox)');
    final goalP = GoalProvider();
    await goalP.init(goalBox: goalBox);
    print('STEP P2-14: after GoalProvider.init(goalBox: goalBox)');

    print('STEP P2-15: before SubGoalProvider.init()');
    final subP = SubGoalProvider();
    await subP.init();
    print('STEP P2-16: after SubGoalProvider.init()');

    print('STEP P2-17: before TaskProvider.init(taskBox: taskBox, notification: FakeNotificationLocalService())');
    final taskP = TaskProvider();
    await taskP.init(taskBox: taskBox, notification: FakeNotificationLocalService());
    print('STEP P2-18: after TaskProvider.init(taskBox: taskBox, notification: FakeNotificationLocalService())');

    print('STEP P2-19: before HiveTestEnv.tearDown');
    await HiveTestEnv.tearDown();
    print('STEP P2-20: after HiveTestEnv.tearDown');
  });

  testWidgets('TEST P3: testWidgets minimal-import provider/data-only flow', (tester) async {
    print('STEP P3-1: before HiveTestEnv.setUp');
    await HiveTestEnv.setUp();
    print('STEP P3-2: after HiveTestEnv.setUp');

    print('STEP P3-3: before clearHiveBoxes');
    await clearHiveBoxes();
    print('STEP P3-4: after clearHiveBoxes');

    print('STEP P3-5: before Hive.box goal/task');
    final goalBox = Hive.box<Goal>(AppBoxes.goal);
    final taskBox = Hive.box<Task>(AppBoxes.task);
    print('STEP P3-6: after Hive.box goal/task');

    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day, 9);

    print('STEP P3-7: before goalBox.add');
    final goalKey = await tester.runAsync(() async {
      return goalBox.add(Goal(title: 'G-Red', priority: 1, color: 0xFFFF0000));
    });
    print('STEP P3-8: after goalBox.add goalKey=$goalKey');

    print('STEP P3-9: before taskBox.add GoalTask');
    await tester.runAsync(() async {
      await taskBox.add(Task(title: 'GoalTask', goalId: goalKey, startAt: day, endAt: day, color: null));
    });
    print('STEP P3-10: after taskBox.add GoalTask');

    print('STEP P3-11: before taskBox.add ScheduleTask');
    await tester.runAsync(() async {
      await taskBox.add(Task(title: 'ScheduleTask', goalId: null, startAt: day, endAt: day, color: 0xFF0000FF));
    });
    print('STEP P3-12: after taskBox.add ScheduleTask');

    print('STEP P3-13: before GoalProvider.init(goalBox: goalBox)');
    final goalP = GoalProvider();
    await goalP.init(goalBox: goalBox);
    print('STEP P3-14: after GoalProvider.init(goalBox: goalBox)');

    print('STEP P3-15: before SubGoalProvider.init()');
    final subP = SubGoalProvider();
    await subP.init();
    print('STEP P3-16: after SubGoalProvider.init()');

    print('STEP P3-17: before TaskProvider.init(taskBox: taskBox, notification: FakeNotificationLocalService())');
    final taskP = TaskProvider();
    await taskP.init(taskBox: taskBox, notification: FakeNotificationLocalService());
    print('STEP P3-18: after TaskProvider.init(taskBox: taskBox, notification: FakeNotificationLocalService())');

    print('STEP P3-19: before HiveTestEnv.tearDown');
    await HiveTestEnv.tearDown();
    print('STEP P3-20: after HiveTestEnv.tearDown');
  });
}
