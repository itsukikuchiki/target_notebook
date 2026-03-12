// integration_test/mvp_goal_breakdown_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/goal.dart';
import 'package:target_notebook/models/sub_goal.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/models/daily_log.dart';

import 'package:target_notebook/providers/goal_provider.dart';
import 'package:target_notebook/providers/sub_goal_provider.dart';
import 'package:target_notebook/providers/task_provider.dart';

import 'package:target_notebook/adapters/goal_tree_adapter.dart';

import 'package:target_notebook/pages/my_journey_page.dart';
import 'package:target_notebook/pages/editors/goal_edit_page.dart';
import 'package:target_notebook/pages/editors/subgoal_edit_page.dart';
import 'package:target_notebook/pages/editors/task_edit_page.dart';

import '../test/helpers/hive_test_env.dart';
import '../test/fakes/fake_notification_local_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await HiveTestEnv.setUp();
  });

  setUp(() async {
    await clearHiveBoxes();

    // SettingsProvider 用 settings box；本测试不使用，但避免串测试（如果已打开就清）
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
    'MVP goal -> subgoal -> task tree expand/collapse + persistence (reboot)',
    (tester) async {
      final notif = FakeNotificationLocalService();

      // 1) 首次启动（空数据）
      await _pumpJourneyHarness(tester, notif: notif);

      // 2) 通过 UI 新增 Goal
      await tester.tap(find.byKey(const Key('btn_open_goal_create')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'G1');
      // priority dropdown 默认 3，不改也行
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // 取出 goalKey（Hive 真实 key）
      final goalBox = Hive.box<Goal>(AppBoxes.goal);
      expect(goalBox.isNotEmpty, true);
      final int goalKey = goalBox.keys.cast<int>().first;

      // 回到 Journey：应该能看到目标标题
      expect(find.text('G1'), findsOneWidget);

      // 3) 通过 UI（PopupMenu）新增子目标
      await _openGoalPopupMenu(tester, goalTitle: 'G1');
      await tester.tap(find.text('新增子目标'));
      await tester.pumpAndSettle();

      // SubGoalEditPage
      await tester.enterText(find.byType(TextFormField).first, 'SG1');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final subBox = Hive.box<SubGoal>(AppBoxes.subGoal);
      expect(subBox.isNotEmpty, true);
      final int subKey = subBox.keys.cast<int>().first;
      expect(subBox.get(subKey)!.goalId, goalKey);

      // 4) 通过 UI（PopupMenu）新增“直接任务”（挂 goalId，无 subGoalId）
      await _openGoalPopupMenu(tester, goalTitle: 'G1');
      await tester.tap(find.text('新增任务'));
      await tester.pumpAndSettle();

      // TaskEditPage（create）：把标题改成 DT1，保持 done=false，不开 alarm
      await tester.enterText(find.byType(TextFormField).first, 'DT1');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // 5) 展开 Goal -> 在子目标 tile 上点 “新增任务” icon
      await tester.tap(find.text('G1')); // tap goal header toggles expand
      await tester.pumpAndSettle();

      expect(find.text('SG1  ·  P3'), findsOneWidget); // 子目标 tile 出现

      // ✅ 避免 tooltip 重名：限定在 SG1 卡片内部找 “新增任务”
      final sgTitle = find.text('SG1  ·  P3');
      final sgCard = find.ancestor(of: sgTitle, matching: find.byType(Card)).first;

      final addTaskBtnInSubGoal = find.descendant(
        of: sgCard,
        matching: find.byTooltip('新增任务'),
      );
      expect(addTaskBtnInSubGoal, findsOneWidget);

      await tester.tap(addTaskBtnInSubGoal);
      await tester.pumpAndSettle();

      // TaskEditPage（create sub task）
      await tester.enterText(find.byType(TextFormField).first, 'ST1');

      // 开启提醒（alarm）并设置 done=true（测试 schedule + 进度）
      await tester.tap(find.byType(Switch).at(0)); // alarm switch（页面第一个 Switch）
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).at(1)); // done switch（第二个 Switch）
      await tester.pumpAndSettle();

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // 6) 回到 Journey：展开 subgoal 查看任务标题（需要展开子目标）
      await tester.tap(find.text('SG1  ·  P3')); // tap subgoal header
      await tester.pumpAndSettle();

      expect(find.text('DT1'), findsOneWidget);
      expect(find.text('ST1'), findsOneWidget);

      // 7) 验证 goal 统计：2 tasks / 1 done
      // MyJourneyPage 在 goal card header text: 'Tasks: done/total ...'
      expect(find.textContaining('Tasks: 1/2'), findsOneWidget);

      // 8) 验证通知 schedule 被调用（ST1 开 alarm；DT1 没开）
      expect(notif.scheduleCalls.isNotEmpty, true);
      expect(notif.scheduleCalls.length, 1);
      expect(notif.scheduleCalls.single.title, 'ST1');

      // 9) 折叠与展开验证（树结构交互）
      // 折叠子目标
      await tester.tap(find.text('SG1  ·  P3'));
      await tester.pumpAndSettle();
      // 折叠后：ST1 应该隐藏（DT1 仍在 direct tasks 区域）
      expect(find.text('ST1'), findsNothing);

      // 折叠 goal
      await tester.tap(find.text('G1'));
      await tester.pumpAndSettle();
      expect(find.text('SG1  ·  P3'), findsNothing);

      // 10) “重启”模拟：重新 pump 一套新的 providers（Hive 不清）
      await _pumpJourneyHarness(tester, notif: notif, reboot: true);

      // 重启后数据仍在
      expect(find.text('G1'), findsOneWidget);

      // 展开并检查统计仍正确
      await tester.tap(find.text('G1'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Tasks: 1/2'), findsOneWidget);

      // 展开子目标再确认 ST1 仍存在
      await tester.tap(find.text('SG1  ·  P3'));
      await tester.pumpAndSettle();
      expect(find.text('ST1'), findsOneWidget);
      expect(find.text('DT1'), findsOneWidget);
    },
  );
}

/// Pump 一个“最小 Journey App Harness”，只包含完成该链路所需 providers/routes。
Future<void> _pumpJourneyHarness(
  WidgetTester tester, {
  required FakeNotificationLocalService notif,
  bool reboot = false,
}) async {
  // providers（每次都创建新的实例来模拟重启）
  final goalP = GoalProvider();
  final subP = SubGoalProvider();
  final taskP = TaskProvider();

  await goalP.init(
    goalBox: Hive.box<Goal>(AppBoxes.goal),
    logBox: Hive.box<DailyLog>(AppBoxes.dailyLog),
  );

  await subP.init(box: Hive.box<SubGoal>(AppBoxes.subGoal));

  // ✅ 与你贴的 TaskProvider.init 签名完全一致
  await taskP.init(
    taskBox: Hive.box<Task>(AppBoxes.task),
    notification: notif,
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
          SubGoalEditPage.route: (_) => const SubGoalEditPage(),
          TaskEditPage.route: (_) => const TaskEditPage(),
        },
        // ✅ 不再在 callback 里用 tester.element；用 Builder 拿到稳定 context
        home: Builder(
          builder: (ctx) => Scaffold(
            appBar: AppBar(
              title: Text(reboot ? 'Journey(Reboot)' : 'Journey'),
              actions: [
                IconButton(
                  key: const Key('btn_open_goal_create'),
                  icon: const Icon(Icons.add),
                  onPressed: () => Navigator.of(ctx).pushNamed(GoalEditPage.route),
                ),
              ],
            ),
            body: const MyJourneyPage(),
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

/// 打开某个 goal 卡片右侧 PopupMenu
Future<void> _openGoalPopupMenu(
  WidgetTester tester, {
  required String goalTitle,
}) async {
  // 目标卡片的 header Row 里有 PopupMenuButton<String>
  // 我们通过：先找到 goal title 的 Text，再向上找 Card，再在 Card 内找 PopupMenuButton
  final titleFinder = find.text(goalTitle);
  expect(titleFinder, findsOneWidget);

  final cardFinder = find.ancestor(of: titleFinder, matching: find.byType(Card));
  expect(cardFinder, findsWidgets);

  final menuFinder = find.descendant(
    of: cardFinder.first,
    matching: find.byType(PopupMenuButton<String>),
  );

  expect(menuFinder, findsOneWidget);
  await tester.tap(menuFinder);
  await tester.pumpAndSettle();
}

