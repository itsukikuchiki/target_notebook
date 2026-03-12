// test/unit/task_provider_update_preserves_fields_test.dart
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

  test('TaskProvider.updateTask preserves unrelated fields when editing an existing Hive object', () async {
    final box = Hive.box<Task>(AppBoxes.task);

    final original = Task(
      title: 'T',
      note: 'note-1',
      startAt: DateTime(2026, 1, 10, 9),
      endAt: DateTime(2026, 1, 10, 10),
      deadline: DateTime(2026, 1, 11),
      isAllDay: false,
      location: 'Ginza',
      participantEmailsRaw: 'a@a.com,b@b.com',
      priority: 2,
      completion: 0.3,
      iconKey: 'briefcase',
      photoPath: '/tmp/photo.png',
      color: 0xFFABCDEF,
      hasAlarm: false,
      alarmAt: null,
      done: false,
    );

    final key = await box.add(original);

    final p = TaskProvider();
    final notif = FakeNotificationLocalService();
    await p.init(taskBox: box, notification: notif);

    // Fetch the same Hive object, mutate only alarm and title, then updateTask(...)
    final t = box.get(key)!;
    t
      ..title = 'T-NEW'
      ..hasAlarm = true
      ..alarmAt = DateTime(2026, 1, 10, 8, 50);

    await p.updateTask(t);

    final saved = box.get(key)!;

    // Changed
    expect(saved.title, 'T-NEW');
    expect(saved.hasAlarm, true);
    expect(saved.alarmAt, isNotNull);

    // Preserved
    expect(saved.note, 'note-1');
    expect(saved.startAt, DateTime(2026, 1, 10, 9));
    expect(saved.endAt, DateTime(2026, 1, 10, 10));
    expect(saved.deadline, DateTime(2026, 1, 11));
    expect(saved.isAllDay, false);
    expect(saved.location, 'Ginza');
    expect(saved.participantEmailsRaw, 'a@a.com,b@b.com');
    expect(saved.priority, 2);
    expect(saved.completion, closeTo(0.3, 1e-9));
    expect(saved.iconKey, 'briefcase');
    expect(saved.photoPath, '/tmp/photo.png');
    expect(saved.color, 0xFFABCDEF);
    expect(saved.done, false);

    // Alarm schedule should have been called at least once
    expect(notif.scheduleCalls.isNotEmpty, true);
    expect(notif.scheduleCalls.last.title, 'T-NEW');
  });
}
