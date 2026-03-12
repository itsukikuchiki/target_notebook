// test/widget/insight_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/pages/insight_page.dart';

import 'package:target_notebook/models/goal.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/models/sub_goal.dart';

import 'package:target_notebook/providers/goal_provider.dart';
import 'package:target_notebook/providers/sub_goal_provider.dart';
import 'package:target_notebook/providers/task_provider.dart';
import 'package:target_notebook/providers/nav_provider.dart';

import 'package:target_notebook/adapters/goal_tree_adapter.dart';
import 'package:target_notebook/adapters/dailylog_adapter.dart';
import 'package:target_notebook/adapters/dailylog_adapter.dart' as log_ui;

import '../helpers/hive_test_env.dart';
import '../fakes/ui_adapters_fakes.dart';
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

/// 更鲁棒的点击：不依赖按钮类型（Outlined/Filled/Text），只依赖文案
Future<void> _tapByText(WidgetTester tester, String label) async {
  final textFinder = find.text(label);
  await _pumpUntilFound(tester, textFinder);

  await tester.ensureVisible(textFinder);
  await tester.pump(const Duration(milliseconds: 50));

  // 尝试找可点击的祖先：常见 Material 交互组件
  final tappable = find.ancestor(
    of: textFinder,
    matching: find.byWidgetPredicate(
      (w) =>
          w is InkWell ||
          w is GestureDetector ||
          w is TextButton ||
          w is ElevatedButton ||
          w is OutlinedButton ||
          w is FilledButton ||
          w is IconButton,
    ),
  );

  if (tappable.evaluate().isNotEmpty) {
    await tester.tap(tappable.first);
  } else {
    // fallback：直接点文字（多数情况下也能 hit-test 到按钮）
    await tester.tap(textFinder);
  }

  await tester.pump(const Duration(milliseconds: 80));
}

class _FakeNavProvider extends ChangeNotifier implements NavProvider {
  int _index = 0;

  @override
  int get index => _index;

  @override
  String get title => 'fake';

  @override
  Future<void> load() async {}

  @override
  Future<void> setIndex(int i) async {
    _index = i;
    notifyListeners();
  }
}

Widget _wrapApp(Widget child) {
  return TickerMode(
    enabled: false,
    child: MaterialApp(home: child),
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

  testWidgets('InsightPage renders weekly stats and loop action buttons update nav index', (tester) async {
    final fakeDaily = FakeDailyLogAdapter();
    fakeDaily.weeklySeed = log_ui.WeeklyVM(
      {
        DateTime(2026, 1, 1): 1.0,
        DateTime(2026, 1, 2): 2.0,
      },
      3.0,
      '测试消息：本周状态不错',
    );

    int g1Key = 0;

    final goalP = GoalProvider();
    final subGoalP = SubGoalProvider();
    final taskP = TaskProvider();

    await tester.runAsync(() async {
      final goalBox = Hive.box<Goal>(AppBoxes.goal);
      final taskBox = Hive.box<Task>(AppBoxes.task);

      g1Key = await goalBox.add(
        Goal(title: 'G1', priority: 1, description: 'd1', color: 0xFF5C6BC0),
      );
      await goalBox.add(
        Goal(title: 'G2', priority: 3, description: 'd2', color: 0xFFEF5350),
      );

      for (int i = 0; i < 10; i++) {
        await taskBox.add(
          Task(
            title: 't$i',
            goalId: g1Key,
            done: i < 4,
            priority: 3,
          ),
        );
      }

      await goalP.init();
      await subGoalP.init();
      await taskP.init(
        taskBox: Hive.box<Task>(AppBoxes.task),
        notification: FakeNotificationLocalService(),
      );
    });

    final tree = GoalTreeAdapter(goalP, subGoalP, taskP);
    final nav = _FakeNavProvider();

    addTearDown(() async {
      fakeDaily.dispose();
      tree.dispose();
      await _unmountApp(tester);
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DailyLogAdapter>.value(value: fakeDaily),
          ChangeNotifierProvider<GoalTreeAdapter>.value(value: tree),
          ChangeNotifierProvider<NavProvider>.value(value: nav),
        ],
        child: _wrapApp(const InsightPage()),
      ),
    );

    await tester.pump(const Duration(milliseconds: 80));

    await _pumpUntilFound(tester, find.text('测试消息：本周状态不错'));

    expect(find.text('测试消息：本周状态不错'), findsOneWidget);
    expect(find.textContaining('Goals · Burndown / Burnup'), findsOneWidget);

    expect(find.text('G1'), findsOneWidget);
    expect(find.text('P1'), findsOneWidget);
    expect(find.textContaining('Done 4 / 10'), findsOneWidget);
    expect(find.textContaining('Remaining 6'), findsOneWidget);

    expect(find.text('G2'), findsOneWidget);
    expect(find.text('P3'), findsOneWidget);

    // ✅ 交互：不依赖 OutlinedButton 类型
    await _tapByText(tester, '看目标');
    expect(nav.index, 0);

    await _tapByText(tester, '去执行');
    expect(nav.index, 1);

    await _tapByText(tester, '去复盘');
    expect(nav.index, 3);
  });

  testWidgets('InsightPage shows empty hint when no goals', (tester) async {
    final fakeDaily = FakeDailyLogAdapter();
    fakeDaily.weeklySeed = log_ui.WeeklyVM({}, 0.0, '');

    final goalP = GoalProvider();
    final subGoalP = SubGoalProvider();
    final taskP = TaskProvider();

    await tester.runAsync(() async {
      await goalP.init();
      await subGoalP.init();
      await taskP.init(
        taskBox: Hive.box<Task>(AppBoxes.task),
        notification: FakeNotificationLocalService(),
      );
    });

    final tree = GoalTreeAdapter(goalP, subGoalP, taskP);
    final nav = _FakeNavProvider();

    addTearDown(() async {
      fakeDaily.dispose();
      tree.dispose();
      await _unmountApp(tester);
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DailyLogAdapter>.value(value: fakeDaily),
          ChangeNotifierProvider<GoalTreeAdapter>.value(value: tree),
          ChangeNotifierProvider<NavProvider>.value(value: nav),
        ],
        child: _wrapApp(const InsightPage()),
      ),
    );

    await tester.pump(const Duration(milliseconds: 80));

    final hint = find.text('还没有目标。去 My Journey 新建一个目标吧。');
    await _pumpUntilFound(tester, hint);
    expect(hint, findsOneWidget);
  });
}
