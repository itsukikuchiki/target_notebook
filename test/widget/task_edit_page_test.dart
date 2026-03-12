import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/providers/task_provider.dart';

import '../helpers/hive_test_env.dart';
import '../fakes/fake_notification_local_service.dart';

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

  test(
    'TaskProvider addTask: saves task with goal/subgoal; done=true never schedules on create',
    () async {
      final notif = FakeNotificationLocalService();

      final taskP = TaskProvider();
      await taskP.init(
        taskBox: Hive.box<Task>(AppBoxes.task),
        notification: notif,
      );

      final alarmAt = DateTime(2026, 1, 10, 9, 0);

      final t = Task(
        title: 'T-UI',
        goalId: 1,
        subGoalId: 2,
        startAt: DateTime(2026, 1, 10, 9, 0),
        endAt: DateTime(2026, 1, 10, 10, 0),
        done: true, // ✅ create 时 done=true => _syncAlarmForCreate 直接 return
        hasAlarm: true,
        alarmAt: alarmAt,
      );

      final res = await taskP.addTask(t);
      expect(res.isSuccess, isTrue);

      final box = Hive.box<Task>(AppBoxes.task);
      expect(box.isNotEmpty, isTrue);

      final saved = box.values.first;
      expect(saved.title, 'T-UI');
      expect(saved.goalId, 1);
      expect(saved.subGoalId, 2);
      expect(saved.done, isTrue);
      expect(saved.hasAlarm, isTrue);
      expect(saved.alarmAt, isNotNull);

      // ✅ done=true => create 不 schedule（与你当前 TaskProvider 实现一致）
      expect(notif.scheduleCalls.length, 0);
    },
    timeout: const Timeout(Duration(seconds: 10)),
  );

  test(
    'TaskProvider addTask: alarm enabled & not done schedules exactly once on create',
    () async {
      final notif = FakeNotificationLocalService();

      final taskP = TaskProvider();
      await taskP.init(
        taskBox: Hive.box<Task>(AppBoxes.task),
        notification: notif,
      );

      final alarmAt = DateTime(2026, 1, 10, 9, 0);

      final t = Task(
        title: 'T-ALARM',
        goalId: 1,
        startAt: DateTime(2026, 1, 10, 9, 0),
        endAt: DateTime(2026, 1, 10, 10, 0),
        done: false,
        hasAlarm: true,
        alarmAt: alarmAt,
      );

      final res = await taskP.addTask(t);
      expect(res.isSuccess, isTrue);

      final box = Hive.box<Task>(AppBoxes.task);
      expect(box.isNotEmpty, isTrue);

      expect(notif.scheduleCalls.length, 1);
      expect(notif.scheduleCalls.single.title, 'T-ALARM');
      expect(notif.scheduleCalls.single.at, alarmAt);
    },
    timeout: const Timeout(Duration(seconds: 10)),
  );
}
