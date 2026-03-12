// integration_test/mvp_task_complete_delete_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/providers/task_provider.dart';
import 'package:target_notebook/adapters/task_adapter.dart';
import 'package:target_notebook/adapters/goal_tree_adapter.dart';
import 'package:target_notebook/pages/daily_page.dart';
import 'package:target_notebook/pages/editors/task_edit_page.dart';

import '../test/helpers/hive_test_env.dart';
import '../test/fakes/fake_notification_local_service.dart';
import '../test/fakes/ui_adapters_fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await HiveTestEnv.setUp();
  });

  setUp(() async {
    await clearHiveBoxes();
    try {
      if (Hive.isBoxOpen('settings')) {
        await Hive.box('settings').clear();
      }
    } catch (_) {}
  });

  tearDownAll(() async {
    await HiveTestEnv.tearDown();
  });

  testWidgets(
    'MVP Task: create -> mark done -> persists in list -> delete from edit page -> removed',
    (tester) async {
      final notif = FakeNotificationLocalService();

      // 1) 启动 Daily
      await _pumpDailyHarness(tester, notif: notif);

      // 2) 新建任务
      await tester.tap(find.byKey(const Key('daily.addTask.fab')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('daily.addTask.title')), 'TD-1');
      await tester.tap(find.byKey(const Key('daily.addTask.save')));
      await tester.pumpAndSettle();

      expect(find.text('TD-1'), findsOneWidget);

      // 取 taskKey（Hive key）
      final taskBox = Hive.box<Task>(AppBoxes.task);
      final int taskKey = taskBox.keys.cast<int>().firstWhere(
            (k) => taskBox.get(k)!.title == 'TD-1',
          );

      // 3) 进入详情页
      await tester.tap(find.byKey(Key('daily.task.item.$taskKey')));
      await tester.pumpAndSettle();

      expect(find.textContaining('编辑日程/任务'), findsOneWidget);

      // 4) 切换 done（TaskEditPage：第 0 个 switch 是 alarm，第 1 个是 done）
      final doneSwitchFinder = find.byType(Switch).at(1);
      expect(doneSwitchFinder, findsOneWidget);

      await tester.tap(doneSwitchFinder);
      await tester.pumpAndSettle();

      // 保存（AppBar 右侧 TextButton）
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // 5) 回到列表：done icon 应为 check_circle
      final tileFinder = find.byKey(Key('daily.task.item.$taskKey'));
      expect(tileFinder, findsOneWidget);

      final checkIconInTile = find.descendant(
        of: tileFinder,
        matching: find.byIcon(Icons.check_circle),
      );
      expect(checkIconInTile, findsOneWidget);

      // 6) 再进详情页，删除
      await tester.tap(tileFinder);
      await tester.pumpAndSettle();

      // TaskEditPage 底部有 “删除任务” 按钮
      final deleteBtn = find.widgetWithText(OutlinedButton, '删除任务');
      expect(deleteBtn, findsOneWidget);

      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // 确认弹窗
      expect(find.text('删除任务？'), findsOneWidget);
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // 7) 列表消失 + Hive 删除 + cancel 被调用
      expect(find.byKey(Key('daily.task.item.$taskKey')), findsNothing);
      expect(Hive.box<Task>(AppBoxes.task).get(taskKey), isNull);

      // deleteTask 会 cancel(key)
      expect(notif.cancelCalls.contains(taskKey), isTrue);
    },
  );
}

Future<void> _pumpDailyHarness(
  WidgetTester tester, {
  required FakeNotificationLocalService notif,
}) async {
  final taskP = TaskProvider();
  await taskP.init(taskBox: Hive.box<Task>(AppBoxes.task), notification: notif);

  final taskAdapter = TaskAdapter(taskP);
  final fakeDaily = FakeDailyLogAdapter();

  // DailyPage 内 week strip 会 Provider.of<GoalTreeAdapter?>(context) / TaskProvider?
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<GoalTreeAdapter?>.value(value: null),
        Provider<TaskProvider?>.value(value: taskP),
        ChangeNotifierProvider.value(value: taskAdapter),
        ChangeNotifierProvider.value(value: fakeDaily),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        routes: {
          TaskEditPage.route: (_) => const TaskEditPage(),
        },
        home: const Scaffold(
          body: DailyPage(),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}
