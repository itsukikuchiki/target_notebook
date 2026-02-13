// test/providers/task_provider_alarm_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/providers/task_provider.dart';
import 'package:target_notebook/services/notification_local_service.dart';

import '../helpers/hive_test_env.dart';

class FakeNotificationLocalService extends NotificationLocalService {
  final scheduled = <int, DateTime>{};
  final canceled = <int>[];

  @override
  Future<void> init() async {}

  @override
  Future<void> ensureReady() async {}

  @override
  Future<void> scheduleOne({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    scheduled[id] = at;
  }

  @override
  Future<void> cancel(int id) async {
    canceled.add(id);
    scheduled.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    canceled.add(-999);
    scheduled.clear();
  }
}

void main() {
  setUpAll(() async {
    await HiveTestEnv.setUp();
  });

  tearDownAll(() async {
    await HiveTestEnv.tearDown();
  });

  setUp(() async {
    await Hive.box<Task>(AppBoxes.task).clear();
  });

  test('addTask schedules alarm when hasAlarm=true and alarmAt future', () async {
    final fake = FakeNotificationLocalService();
    final p = TaskProvider();
    await p.init(taskBox: Hive.box<Task>(AppBoxes.task));
    p.bindNotificationService(fake);

    final future = DateTime.now().add(const Duration(hours: 2));
    final t = Task(
      title: 'A',
      hasAlarm: true,
      alarmAt: future,
      note: 'note',
    );

    final res = await p.addTask(t);
    expect(res.isSuccess, true);

    final newKey = (res as dynamic).value as int; // Success<int>(key)
    expect(fake.scheduled.containsKey(newKey), true);
    expect(fake.scheduled[newKey], future);
  });

  test('toggleTaskDone(true) cancels alarm', () async {
    final fake = FakeNotificationLocalService();
    final p = TaskProvider();
    await p.init(taskBox: Hive.box<Task>(AppBoxes.task));
    p.bindNotificationService(fake);

    final future = DateTime.now().add(const Duration(hours: 2));
    final key = await Hive.box<Task>(AppBoxes.task).add(
      Task(title: 'B', hasAlarm: true, alarmAt: future),
    );

    // 手动触发一次 update，让 provider 认为已有 alarm
    final t = Hive.box<Task>(AppBoxes.task).get(key)!;
    await p.updateTask(t);

    // 再完成 -> cancel
    await p.toggleTaskDone(key, true);
    expect(fake.canceled.contains(key), true);
  });

  test('updateTask reschedules when alarmAt changes', () async {
    final fake = FakeNotificationLocalService();
    final p = TaskProvider();
    await p.init(taskBox: Hive.box<Task>(AppBoxes.task));
    p.bindNotificationService(fake);

    final t = Task(
      title: 'C',
      hasAlarm: true,
      alarmAt: DateTime.now().add(const Duration(hours: 2)),
    );

    final key = await Hive.box<Task>(AppBoxes.task).add(t);

    // 第一次更新（触发 schedule）
    final obj = Hive.box<Task>(AppBoxes.task).get(key)!;
    await p.updateTask(obj);
    expect(fake.scheduled.containsKey(key), true);

    // 改时间（应 cancel + schedule）
    final obj2 = Hive.box<Task>(AppBoxes.task).get(key)!;
    final next = DateTime.now().add(const Duration(hours: 5));
    obj2.alarmAt = next;
    await p.updateTask(obj2);

    expect(fake.canceled.contains(key), true);
    expect(fake.scheduled[key], next);
  });

  test('deleteTask cancels alarm', () async {
    final fake = FakeNotificationLocalService();
    final p = TaskProvider();
    await p.init(taskBox: Hive.box<Task>(AppBoxes.task));
    p.bindNotificationService(fake);

    final key = await Hive.box<Task>(AppBoxes.task).add(
      Task(
        title: 'D',
        hasAlarm: true,
        alarmAt: DateTime.now().add(const Duration(hours: 2)),
      ),
    );

    await p.deleteTask(key);

    expect(fake.canceled.contains(key), true);
    expect(Hive.box<Task>(AppBoxes.task).get(key), null);
  });
}

