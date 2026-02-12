import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/goal.dart';
import 'package:target_notebook/models/sub_goal.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/models/ai_breakdown_models.dart';

import 'package:target_notebook/providers/goal_provider.dart';
import 'package:target_notebook/providers/sub_goal_provider.dart';
import 'package:target_notebook/providers/task_provider.dart';
import 'package:target_notebook/providers/ai_breakdown_provider.dart';

import 'package:target_notebook/adapters/goal_tree_adapter.dart';
import 'package:target_notebook/pages/my_journey_page.dart';

import 'package:target_notebook/services/ai_service.dart';
import 'package:target_notebook/pages/ai_breakdown/ai_breakdown_input_sheet.dart';
import 'package:target_notebook/pages/ai_breakdown/ai_breakdown_preview_page.dart';

import 'helpers/hive_test_env.dart'; // ensureHiveReady()

class FakeAiServiceSuccess extends AiService {
  FakeAiServiceSuccess() : super(apiKey: 'test');

  @override
  Future<AiBreakdownResult> breakdownGoal({
    required String title,
    String? description,
    DateTime? deadline,
    int weeklyHours = 5,
    String locale = 'zh',
  }) async {
    return AiBreakdownResult(subGoals: [
      AiSubGoalDraft(
        title: '定义完成标准',
        description: '把目标变清晰',
        why: '避免返工',
        estimateDays: 2,
        priority: 1,
        tasks: [
          AiTaskDraft(title: '写下完成标准（3条）', minutes: 30, dueInDays: 0, priority: 1),
          AiTaskDraft(title: '列出资源与限制', minutes: 30, dueInDays: 1, priority: 2),
        ],
      ),
    ]);
  }
}

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 260,
  Duration step = const Duration(milliseconds: 50),
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
  }
  await tester.pump();
  expect(finder, findsOneWidget);
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await pumpUntilFound(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(finder, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 250));
}

dynamic _installIgnoreOverflowErrors() {
  final prev = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final msg = details.exceptionAsString();
    if (msg.contains('A RenderFlex overflowed by')) return;
    if (prev != null) return prev(details);
    FlutterError.dumpErrorToConsole(details);
  };
  return prev;
}

void _restoreFlutterErrorHandler(dynamic previous) {
  FlutterError.onError = previous;
}

Future<void> waitForHiveWrite(
  WidgetTester tester, {
  required int expectSubGoals,
  required int expectTasks,
  Duration timeout = const Duration(seconds: 8),
  Duration tick = const Duration(milliseconds: 50),
  String label = 'wait hive write',
}) async {
  bool done() {
    final sg = Hive.box<SubGoal>(AppBoxes.subGoal).values.length;
    final tk = Hive.box<Task>(AppBoxes.task).values.length;
    return sg == expectSubGoals && tk == expectTasks;
  }

  final end = DateTime.now().add(timeout);

  await tester.runAsync(() async {
    while (DateTime.now().isBefore(end)) {
      if (done()) return;
      await Future<void>.delayed(tick);
      await tester.pump(tick);
      if (done()) return;
    }
  });

  if (done()) return;

  final sg = Hive.box<SubGoal>(AppBoxes.subGoal).values.length;
  final tk = Hive.box<Task>(AppBoxes.task).values.length;
  fail('$label timeout: subGoals=$sg tasks=$tk (expected $expectSubGoals/$expectTasks)');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ensureHiveReady();
    await Hive.openBox<Goal>(AppBoxes.goal);
    await Hive.openBox<SubGoal>(AppBoxes.subGoal);
    await Hive.openBox<Task>(AppBoxes.task);
  });

  setUp(() async {
    await Hive.box<Goal>(AppBoxes.goal).clear();
    await Hive.box<SubGoal>(AppBoxes.subGoal).clear();
    await Hive.box<Task>(AppBoxes.task).clear();
  });

  // ✅ 关键：Hive.close 偶发卡死 → 给 timeout，避免整个 flutter test 挂住
  tearDownAll(() async {
    try {
      await Hive.close().timeout(const Duration(seconds: 2));
    } catch (_) {
      // ignore
    }
  });

  Future<int> _seedOneGoal() async {
    final goalBox = Hive.box<Goal>(AppBoxes.goal);
    return goalBox.add(
      Goal(
        title: '通过 FP2',
        description: '两个月内通过考试',
        priority: 1,
        color: 0xFF5C6BC0,
      ),
    );
  }

  Future<Widget> _buildApp() async {
    final goalP = GoalProvider();
    final subGoalP = SubGoalProvider();
    final taskP = TaskProvider();

    await goalP.init();
    await subGoalP.init();
    await taskP.init();

    final goalTree = GoalTreeAdapter(goalP, subGoalP, taskP);

    final ai = FakeAiServiceSuccess();
    final aiP = AiBreakdownProvider(
      ai: ai,
      goalProvider: goalP,
      subGoalProvider: subGoalP,
      taskProvider: taskP,
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: goalP),
        ChangeNotifierProvider.value(value: subGoalP),
        ChangeNotifierProvider.value(value: taskP),
        ChangeNotifierProvider.value(value: goalTree),
        Provider.value(value: ai),
        ChangeNotifierProvider.value(value: aiP),
      ],
      child: const MaterialApp(home: Scaffold(body: MyJourneyPage())),
    );
  }

  void _setBigTestSurface(TestWidgetsFlutterBinding binding) {
    binding.window.devicePixelRatioTestValue = 1.0;
    binding.window.physicalSizeTestValue = const Size(1200, 1400);
  }

  void _clearTestSurface(TestWidgetsFlutterBinding binding) {
    binding.window.clearPhysicalSizeTestValue();
    binding.window.clearDevicePixelRatioTestValue();
  }

  testWidgets(
    'MyJourney entry: popup menu -> AI breakdown -> save writes into Hive',
    (tester) async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      _setBigTestSurface(binding);
      addTearDown(() => _clearTestSurface(binding));

      final prevHandler = _installIgnoreOverflowErrors();
      addTearDown(() => _restoreFlutterErrorHandler(prevHandler));

      await tester.pump();

      late Widget app;

      await tester.runAsync(() async {
        await _seedOneGoal();
        app = await _buildApp();
      });

      await tester.pumpWidget(app);
      await tester.pump(const Duration(milliseconds: 600));

      await pumpUntilFound(tester, find.text('通过 FP2'));

      final menuBtn = find.byType(PopupMenuButton<String>).first;
      await tapVisible(tester, menuBtn);

      await tapVisible(tester, find.text('AI 目标分解'));

      await pumpUntilFound(tester, find.byType(AiBreakdownInputSheet));

      await tapVisible(tester, find.text('生成'));

      await pumpUntilFound(tester, find.byType(AiBreakdownPreviewPage));

      await tester.runAsync(() async {
        await tapVisible(tester, find.text('保存'));
      });

      await waitForHiveWrite(
        tester,
        expectSubGoals: 1,
        expectTasks: 2,
        label: 'wait hive save (journey)',
      );

      expect(Hive.box<SubGoal>(AppBoxes.subGoal).values.length, 1);
      expect(Hive.box<Task>(AppBoxes.task).values.length, 2);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}

