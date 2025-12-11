import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/fakes.dart';

import 'package:target_notebook/widgets/plus_panel.dart';
import 'package:target_notebook/pages/editors/goal_edit_page.dart';
import 'package:target_notebook/pages/editors/task_edit_page.dart';
import 'package:target_notebook/pages/editors/reflection_edit_page.dart';

import 'package:target_notebook/adapters/goal_adapter.dart' as ui;
import 'package:target_notebook/adapters/task_adapter.dart' as ui;
import 'package:target_notebook/adapters/dailylog_adapter.dart' as ui;

import 'package:target_notebook/providers/nav_provider.dart';

void main() {
  Widget buildApp() => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => NavProvider()),
          ChangeNotifierProvider<ui.GoalAdapter>.value(
            value: FakeGoalAdapter(),
          ),
          ChangeNotifierProvider<ui.TaskAdapter>.value(
            value: FakeTaskAdapter(),
          ),
          ChangeNotifierProvider<ui.DailyLogAdapter>.value(
            value: FakeDailyLogAdapter(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: const PlusPanel(),
          ),
        ),
      );

  testWidgets('Plus panel routes', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Add Goal
    await tester.tap(plusTile('Add Goal'));
    await tester.pumpAndSettle();
    expect(find.byType(GoalEditPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Add Task
    await tester.tap(plusTile('Add Task'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Add Reflection
    await tester.tap(plusTile('Add Reflection'));
    await tester.pumpAndSettle();
    expect(find.byType(ReflectionEditPage), findsOneWidget);
  });
}

