// integration_test/mvp_goal_delete_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/goal.dart';
import 'package:target_notebook/models/sub_goal.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/providers/goal_provider.dart';
import 'package:target_notebook/providers/sub_goal_provider.dart';
import 'package:target_notebook/providers/task_provider.dart';
import 'package:target_notebook/adapters/goal_tree_adapter.dart';
import 'package:target_notebook/pages/my_journey_page.dart';
import 'package:target_notebook/pages/editors/goal_edit_page.dart';

import '../test/helpers/hive_test_env.dart';
import '../test/fakes/fake_notification_local_service.dart';

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
    'MVP Goal: delete from GoalEditPage removes it from MyJourney list',
    (tester) async {
      // Arrange: seed a goal
      const goalTitle = 'GOAL-DEL-1';
      const goalColor = 0xFF5C6BC0;

      final goalBox = Hive.box<Goal>(AppBoxes.goal);
      final subBox = Hive.box<SubGoal>(AppBoxes.subGoal);
      final taskBox = Hive.box<Task>(AppBoxes.task);

      final goalKey = await goalBox.add(
        Goal(
          title: goalTitle,
          priority: 1,
          color: goalColor,
        ),
      );

      // init providers
      final goalP = GoalProvider();
      await goalP.init(goalBox: goalBox);

      final subP = SubGoalProvider();
      await subP.init(subGoalBox: subBox);

      final taskP = TaskProvider();
      await taskP.init(
        taskBox: taskBox,
        notification: FakeNotificationLocalService(),
      );

      final tree = GoalTreeAdapter(goalP, subP, taskP);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: goalP),
            ChangeNotifierProvider.value(value: subP),
            ChangeNotifierProvider.value(value: taskP),
            ChangeNotifierProvider.value(value: tree),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            routes: {
              GoalEditPage.route: (_) => const GoalEditPage(),
            },
            home: const Scaffold(body: MyJourneyPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should see goal
      expect(find.text(goalTitle), findsOneWidget);

      // Find the card that contains this goal title
      final goalCard = find.ancestor(
        of: find.text(goalTitle),
        matching: find.byType(Card),
      );
      expect(goalCard, findsWidgets);

      // Open popup menu on that goal card
      final popup = find.descendant(
        of: goalCard.first,
        matching: find.byType(PopupMenuButton<String>),
      );
      expect(popup, findsOneWidget);

      await tester.tap(popup.first);
      await tester.pumpAndSettle();

      // Choose "编辑目标" (fallback to text match; ideally add a Key in source later)
      final editEntry = find.text('编辑目标');
      expect(editEntry, findsWidgets);
      await tester.tap(editEntry.first);
      await tester.pumpAndSettle();

      // Now on GoalEditPage: delete icon
      final deleteIcon = find.byIcon(Icons.delete_outline);
      expect(deleteIcon, findsOneWidget);
      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();

      // Confirm dialog
      expect(find.text('删除目标？'), findsOneWidget);

      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);

      final confirmDeleteBtn = find.descendant(
        of: dialog,
        matching: find.text('删除'),
      );
      expect(confirmDeleteBtn, findsWidgets);

      await tester.tap(confirmDeleteBtn.first);
      await tester.pumpAndSettle();

      // Back to MyJourney, goal should be gone
      expect(Hive.box<Goal>(AppBoxes.goal).get(goalKey), isNull);
      expect(find.text(goalTitle), findsNothing);
    },
  );
}
