import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/fakes.dart';

import 'package:target_notebook/widgets/plus_panel.dart';
import 'package:target_notebook/pages/editors/goal_edit_page.dart';
import 'package:target_notebook/pages/editors/task_edit_page.dart';
import 'package:target_notebook/pages/editors/reflection_edit_page.dart';

import 'package:target_notebook/adapters/goal_adapter.dart' as goal_ui;
import 'package:target_notebook/adapters/task_adapter.dart' as task_ui;
import 'package:target_notebook/adapters/dailylog_adapter.dart' as log_ui;

import 'package:target_notebook/providers/nav_provider.dart';

void main() {
  Widget buildApp() => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => NavProvider()),
          ChangeNotifierProvider<goal_ui.GoalAdapter>.value(
            value: FakeGoalAdapter(),
          ),
          ChangeNotifierProvider<task_ui.TaskAdapter>.value(
            value: FakeTaskAdapter(),
          ),
          ChangeNotifierProvider<log_ui.DailyLogAdapter>.value(
            value: FakeDailyLogAdapter(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: const PlusPanel(),
          ),
        ),
      );

  Future<void> _goBack(WidgetTester tester) async {
    // 优先点 Material back button（AppBar 的 leading）
    final backBtn = find.byType(BackButton);
    if (backBtn.evaluate().isNotEmpty) {
      await tester.tap(backBtn);
      await tester.pumpAndSettle();
      return;
    }

    // 兜底：直接 pop（不依赖页面是否有可见 back button）
    final navState = tester.state<NavigatorState>(find.byType(Navigator));
    navState.pop();
    await tester.pumpAndSettle();
  }

  testWidgets('Plus panel routes', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Add Goal
    await tester.tap(plusTile('Add Goal'));
    await tester.pumpAndSettle();
    expect(find.byType(GoalEditPage), findsOneWidget);
    await _goBack(tester);

    // Add Task
    await tester.tap(plusTile('Add Task'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditPage), findsOneWidget);
    await _goBack(tester);

    // Add Reflection
    await tester.tap(plusTile('Add Reflection'));
    await tester.pumpAndSettle();
    expect(find.byType(ReflectionEditPage), findsOneWidget);
  });
}

