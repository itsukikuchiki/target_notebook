import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/fakes.dart';

import 'package:target_notebook/app.dart';
import 'package:target_notebook/pages/editors/goal_edit_page.dart';
import 'package:target_notebook/pages/editors/task_edit_page.dart';
import 'package:target_notebook/pages/editors/reflection_edit_page.dart';

import 'package:target_notebook/adapters/goal_adapter.dart' as ui;
import 'package:target_notebook/adapters/task_adapter.dart' as ui;
import 'package:target_notebook/adapters/dailylog_adapter.dart' as ui;

import 'package:target_notebook/providers/nav_provider.dart';

void main() {
  Widget buildApp({
    required FakeGoalAdapter goal,
    required FakeTaskAdapter task,
    required FakeDailyLogAdapter log,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NavProvider()),
        ChangeNotifierProvider<ui.GoalAdapter>.value(value: goal),
        ChangeNotifierProvider<ui.TaskAdapter>.value(value: task),
        ChangeNotifierProvider<ui.DailyLogAdapter>.value(value: log),
      ],
      child: const TargetNotebookApp(),
    );
  }

  group('W3 App smoke', () {
    testWidgets('底部导航：五页标题可切换', (tester) async {
      final g = FakeGoalAdapter()..seed = [goal(1, '目标A', 0.4, 2, 5)];
      final t = FakeTaskAdapter()
        ..seedForDay(DateTime.now(), [FakeTaskVM(1, '晨跑 3km', DateTime.now(), false)]);
      final l = FakeDailyLogAdapter();

      await tester.pumpWidget(buildApp(goal: g, task: t, log: l));
      await tester.pumpAndSettle();

      // ✅ AppBar + NavBar 都会有文字，所以用 findsWidgets
      expect(find.text('My Journey'), findsWidgets);

      await tester.tap(find.text('Daily'));
      await tester.pumpAndSettle();
      expect(find.text('Daily'), findsWidgets);

      await tester.tap(find.text('Insight'));
      await tester.pumpAndSettle();
      expect(find.text('Insight'), findsWidgets);

      await tester.tap(find.text('Reflection'));
      await tester.pumpAndSettle();
      expect(find.text('Reflection'), findsWidgets);

      await tester.tap(find.text('Me'));
      await tester.pumpAndSettle();
      expect(find.text('Me'), findsWidgets);
    });

    testWidgets('My Journey：目标卡可见', (tester) async {
      final g = FakeGoalAdapter()..seed = [goal(1, '通过 FP2', 0.5, 5, 10)];
      final t = FakeTaskAdapter();
      final l = FakeDailyLogAdapter();

      await tester.pumpWidget(buildApp(goal: g, task: t, log: l));
      await tester.pumpAndSettle();

      // ✅ 改成 findsWidgets，避免标题重复误判
      expect(find.text('My Journey'), findsWidgets);
      expect(find.text('通过 FP2'), findsOneWidget);
      expect(find.textContaining('进度 50%'), findsOneWidget);
    });

    testWidgets('Daily：今日任务可见且可勾选', (tester) async {
      final today = DateUtils.dateOnly(DateTime.now());
      final g = FakeGoalAdapter();
      final t = FakeTaskAdapter()
        ..seedForDay(today, [FakeTaskVM(1, '复习章节 5', today, false)]);
      final l = FakeDailyLogAdapter();

      await tester.pumpWidget(buildApp(goal: g, task: t, log: l));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Daily'));
      await tester.pumpAndSettle();

      expect(find.text('复习章节 5'), findsOneWidget);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
    });

    testWidgets('Insight：图表与圆环可见', (tester) async {
      final start = DateTime.now().subtract(const Duration(days: 6));
      final map = <DateTime, double>{};
      for (int i = 0; i < 7; i++) {
        final d = DateTime(start.year, start.month, start.day + i);
        map[DateUtils.dateOnly(d)] = 1.0;
      }
      final l = FakeDailyLogAdapter()
        ..weeklySeed = ui.WeeklyStatsVM(map, 0.6, '本周累计 7.0 小时，完成率 60%。');

      await tester.pumpWidget(buildApp(
        goal: FakeGoalAdapter(),
        task: FakeTaskAdapter(),
        log: l,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Insight'));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('本周累计 7.0 小时，完成率 60%。'), findsOneWidget);
    });

    testWidgets('Reflection：最近一条反思可见', (tester) async {
      final l = FakeDailyLogAdapter()
        ..reflectionsSeed = [
          ReflectionStub(DateTime(2025, 10, 1), '今天状态不错，完成关键任务。')
        ];

      await tester.pumpWidget(buildApp(
        goal: FakeGoalAdapter(),
        task: FakeTaskAdapter(),
        log: l,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reflection'));
      await tester.pumpAndSettle();

      expect(find.textContaining('今天状态不错'), findsOneWidget);
    });

    testWidgets('悬浮「＋」→ 选择项跳转到编辑页', (tester) async {
      final g = FakeGoalAdapter();
      final t = FakeTaskAdapter();
      final l = FakeDailyLogAdapter();

      await tester.pumpWidget(buildApp(goal: g, task: t, log: l));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.tap(plusTile('Add Task'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, '新增任务'), findsOneWidget);
      expect(find.byType(TaskEditPage), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(plusTile('Add Reflection'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, '新增反思'), findsOneWidget);
      expect(find.byType(ReflectionEditPage), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
    });
  });
}

