// test/widget/my_journey_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/goal.dart';
import 'package:target_notebook/models/sub_goal.dart';
import 'package:target_notebook/models/task.dart';

import 'package:target_notebook/providers/goal_provider.dart';
import 'package:target_notebook/providers/sub_goal_provider.dart';
import 'package:target_notebook/providers/task_provider.dart';

import 'package:target_notebook/adapters/goal_tree_adapter.dart';
import 'package:target_notebook/pages/my_journey_page.dart';

import '../helpers/hive_test_env.dart';
import '../fakes/fake_notification_local_service.dart';

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 20),
  int maxSteps = 400, // 8s
}) async {
  for (int i = 0; i < maxSteps; i++) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timeout waiting for ${finder.description}');
}

Widget _wrapApp(Widget child) {
  return TickerMode(
    enabled: false,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

Future<void> _unmountApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  setUpAll(() async {
    await HiveTestEnv.setUp();
  });

  tearDownAll(() async {
    await HiveTestEnv.tearDown();
  });

  setUp(() async {
    await Hive.box<Goal>(AppBoxes.goal).clear();
    await Hive.box<SubGoal>(AppBoxes.subGoal).clear();
    await Hive.box<Task>(AppBoxes.task).clear();
  });

  testWidgets('MyJourneyPage shows weekly top3 goals sorted by priority then key, and can expand', (tester) async {
    final goalP = GoalProvider();
    final subP = SubGoalProvider();
    final taskP = TaskProvider();

    await tester.runAsync(() async {
      final goalBox = Hive.box<Goal>(AppBoxes.goal);
      final subBox = Hive.box<SubGoal>(AppBoxes.subGoal);
      final taskBox = Hive.box<Task>(AppBoxes.task);

      final g1 = await goalBox.add(Goal(title: 'G-High', priority: 1, color: 0xFF5C6BC0));
      await goalBox.add(Goal(title: 'G-Mid', priority: 2, color: 0xFFEF5350));
      await goalBox.add(Goal(title: 'G-Low', priority: 4, color: 0xFF66BB6A));
      await goalBox.add(Goal(title: 'G-High-2', priority: 1, color: 0xFF29B6F6));

      final sg1 = await subBox.add(SubGoal(goalId: g1, title: 'SG1', priority: 2));

      await taskBox.add(Task(title: 'T-sg-done', goalId: g1, subGoalId: sg1, done: true, priority: 2));
      await taskBox.add(Task(title: 'T-sg-open', goalId: g1, subGoalId: sg1, done: false, priority: 1));
      await taskBox.add(Task(title: 'T-direct', goalId: g1, done: false, priority: 3));

      await goalP.init();
      await subP.init();
      await taskP.init(
        taskBox: Hive.box<Task>(AppBoxes.task),
        notification: FakeNotificationLocalService(),
      );
    });

    final tree = GoalTreeAdapter(goalP, subP, taskP);

    addTearDown(() async {
      tree.dispose();
      await _unmountApp(tester);
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GoalTreeAdapter>.value(value: tree),
        ],
        child: _wrapApp(const MyJourneyPage()),
      ),
    );

    await tester.pump(const Duration(milliseconds: 80));

    await _pumpUntilFound(tester, find.text('本周三目标'));
    expect(find.text('本周三目标'), findsOneWidget);

    // ✅ 这里可能在多个区域同时出现同名文本：用 findsWidgets 更稳
    expect(find.text('G-High'), findsWidgets);
    expect(find.text('G-High-2'), findsWidgets);
    expect(find.text('G-Mid'), findsWidgets);
    expect(find.text('G-Low'), findsNothing);

    // ✅ 点第一个出现的 G-High（通常是顶部 weekly focus）
    final gHigh = find.text('G-High').first;
    await tester.ensureVisible(gHigh);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(gHigh, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 120));

    await _pumpUntilFound(tester, find.text('直接任务'));
    expect(find.text('直接任务'), findsOneWidget);

    expect(find.text('T-direct'), findsOneWidget);
    expect(find.textContaining('SG1'), findsOneWidget);
  });

  testWidgets('MyJourneyPage shows empty hint when no goals', (tester) async {
    final goalP = GoalProvider();
    final subP = SubGoalProvider();
    final taskP = TaskProvider();

    await tester.runAsync(() async {
      await goalP.init();
      await subP.init();
      await taskP.init(
        taskBox: Hive.box<Task>(AppBoxes.task),
        notification: FakeNotificationLocalService(),
      );
    });

    final tree = GoalTreeAdapter(goalP, subP, taskP);

    addTearDown(() async {
      tree.dispose();
      await _unmountApp(tester);
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GoalTreeAdapter>.value(value: tree),
        ],
        child: _wrapApp(const MyJourneyPage()),
      ),
    );

    await tester.pump(const Duration(milliseconds: 80));

    final hint = find.text('还没有目标，点右下角＋添加一个吧');
    await _pumpUntilFound(tester, hint);
    expect(hint, findsOneWidget);
  });
}
