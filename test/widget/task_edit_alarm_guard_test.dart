import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/pages/editors/task_edit_page.dart';
import 'package:target_notebook/providers/task_provider.dart';

import '../helpers/hive_test_env.dart';
import '../fakes/fake_notification_local_service.dart';

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

  testWidgets(
    'TaskEditPage create: hasAlarm=true with alarmAt null -> defaults to startAt-10min (future startAt)',
    (tester) async {
      final notif = FakeNotificationLocalService();

      final taskP = TaskProvider();
      await taskP.init(
        taskBox: Hive.box<Task>(AppBoxes.task),
        notification: notif,
      );

      final now = DateTime.now();
      final tomorrow =
          DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      final expectedStartAt =
          DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0);
      final expectedAlarmAt =
          expectedStartAt.subtract(const Duration(minutes: 10));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: taskP),
          ],
          child: MaterialApp(
            routes: {
              TaskEditPage.route: (_) => const TaskEditPage(),
            },
            home: _OpenTaskEditOnFirstFrame(
              args: {
                'date': tomorrow,
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(TaskEditPage), findsOneWidget);

      final alarmSwitch = find.byType(Switch).first;
      expect(alarmSwitch, findsOneWidget);

      await tester.tap(alarmSwitch);
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('保存'));
      await tester.pump(const Duration(milliseconds: 300));

      final box = Hive.box<Task>(AppBoxes.task);
      expect(box.isNotEmpty, true);

      // ✅ 只断言“开启了 alarm 的那条”
      final alarmed = box.values.where((t) => t.hasAlarm == true).toList();
      expect(alarmed.isNotEmpty, true);

      final saved = alarmed.last;
      expect(saved.startAt, expectedStartAt);
      expect(saved.alarmAt, expectedAlarmAt);
    },
  );

  testWidgets(
    'TaskEditPage create: alarmAt default falls in past -> guards to now+1h (roughly)',
    (tester) async {
      final notif = FakeNotificationLocalService();

      final taskP = TaskProvider();
      await taskP.init(
        taskBox: Hive.box<Task>(AppBoxes.task),
        notification: notif,
      );

      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 1));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: taskP),
          ],
          child: MaterialApp(
            routes: {
              TaskEditPage.route: (_) => const TaskEditPage(),
            },
            home: _OpenTaskEditOnFirstFrame(
              args: {
                'date': yesterday,
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(TaskEditPage), findsOneWidget);

      final alarmSwitch = find.byType(Switch).first;
      await tester.tap(alarmSwitch);
      await tester.pump(const Duration(milliseconds: 200));

      final beforeSave = DateTime.now();

      await tester.tap(find.text('保存'));
      await tester.pump(const Duration(milliseconds: 300));

      final box = Hive.box<Task>(AppBoxes.task);
      expect(box.isNotEmpty, true);

      final alarmed = box.values.where((t) => t.hasAlarm == true).toList();
      expect(alarmed.isNotEmpty, true);

      final saved = alarmed.last;
      expect(saved.alarmAt, isNotNull);

      final a = saved.alarmAt!;
      final lower = beforeSave.add(const Duration(minutes: 50));
      final upper = beforeSave.add(const Duration(hours: 1, minutes: 10));

      expect(a.isAfter(lower) || a.isAtSameMomentAs(lower), true);
      expect(a.isBefore(upper) || a.isAtSameMomentAs(upper), true);
    },
  );
}

class _OpenTaskEditOnFirstFrame extends StatefulWidget {
  final Map<String, dynamic> args;
  const _OpenTaskEditOnFirstFrame({required this.args});

  @override
  State<_OpenTaskEditOnFirstFrame> createState() =>
      _OpenTaskEditOnFirstFrameState();
}

class _OpenTaskEditOnFirstFrameState extends State<_OpenTaskEditOnFirstFrame> {
  bool _opened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Navigator.of(context)
          .pushNamed(TaskEditPage.route, arguments: widget.args);
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('home')),
    );
  }
}
