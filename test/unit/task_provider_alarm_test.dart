// test/unit/task_provider_alarm_test.dart
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

  test('addTask with alarm schedules once', () async {
    final box = Hive.box<Task>(AppBoxes.task);
    final notif = FakeNotificationLocalService();

    final p = TaskProvider();
    await p.init(taskBox: box, notification: notif);

    final at = DateTime.now().add(const Duration(hours: 2));
    final t = Task(
      title: 'A',
      startAt: DateTime.now(),
      hasAlarm: true,
      alarmAt: at,
      note: 'note',
      done: false,
    );

    final r = await p.addTask(t);
    expect(r.isSuccess, true);

    expect(notif.scheduleCalls.length, 1);
    expect(notif.scheduleCalls.single.title, 'A');
    expect(notif.scheduleCalls.single.body, 'note');
  });

  test('updateTask enabling alarm schedules', () async {
    final box = Hive.box<Task>(AppBoxes.task);
    final notif = FakeNotificationLocalService();

    final p = TaskProvider();
    await p.init(taskBox: box, notification: notif);

    final key = await box.add(Task(
      title: 'B',
      startAt: DateTime.now(),
      done: false,
      hasAlarm: false,
    ));

    // 建立 snapshot（模拟真实使用）
    await p.updateTask(box.get(key)!);

    notif.scheduleCalls.clear();

    // ✅ 用 Hive 管理的对象（自带 key），避免 patch.key setter
    final patch = box.get(key)!;
    patch
      ..hasAlarm = true
      ..alarmAt = DateTime.now().add(const Duration(hours: 3))
      ..note = 'hello';

    await p.updateTask(patch);

    expect(notif.scheduleCalls.length, 1);
    expect(notif.scheduleCalls.single.id, key);
    expect(notif.scheduleCalls.single.body, 'hello');
  });

  test('updateTask changing alarmAt cancels then schedules', () async {
    final box = Hive.box<Task>(AppBoxes.task);
    final notif = FakeNotificationLocalService();

    final p = TaskProvider();
    await p.init(taskBox: box, notification: notif);

    final key = await box.add(Task(
      title: 'C',
      startAt: DateTime.now(),
      done: false,
      hasAlarm: true,
      alarmAt: DateTime.now().add(const Duration(hours: 1)),
      note: 'n1',
    ));

    await p.updateTask(box.get(key)!); // snapshot

    notif.cancelCalls.clear();
    notif.scheduleCalls.clear();

    // ✅ 用 Hive 管理的对象（自带 key）
    final patch = box.get(key)!;
    patch.alarmAt = DateTime.now().add(const Duration(hours: 2));

    await p.updateTask(patch);

    expect(notif.cancelCalls, [key]);
    expect(notif.scheduleCalls.length, 1);
    expect(notif.scheduleCalls.single.id, key);
  });

  test('toggleTaskDone(true) cancels', () async {
    final box = Hive.box<Task>(AppBoxes.task);
    final notif = FakeNotificationLocalService();

    final p = TaskProvider();
    await p.init(taskBox: box, notification: notif);

    final key = await box.add(Task(
      title: 'D',
      startAt: DateTime.now(),
      done: false,
      hasAlarm: true,
      alarmAt: DateTime.now().add(const Duration(hours: 2)),
    ));

    await p.updateTask(box.get(key)!); // snapshot

    notif.cancelCalls.clear();
    await p.toggleTaskDone(key, true);

    expect(notif.cancelCalls, [key]);
  });

  test('deleteTask cancels then deletes', () async {
    final box = Hive.box<Task>(AppBoxes.task);
    final notif = FakeNotificationLocalService();

    final p = TaskProvider();
    await p.init(taskBox: box, notification: notif);

    final key = await box.add(Task(
      title: 'E',
      startAt: DateTime.now(),
      done: false,
      hasAlarm: true,
      alarmAt: DateTime.now().add(const Duration(hours: 2)),
    ));

    await p.deleteTask(key);

    expect(notif.cancelCalls, [key]);
    expect(box.get(key), isNull);
  });
}

