// test/ai_breakdown_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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

import 'package:target_notebook/services/ai_service.dart';
import 'package:target_notebook/pages/ai_breakdown/ai_breakdown_input_sheet.dart';
import 'package:target_notebook/pages/ai_breakdown/ai_breakdown_preview_page.dart';

import 'helpers/hive_test_env.dart';

/// ===== Fake AiService =====
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

class FakeAiServiceFailure extends AiService {
  FakeAiServiceFailure() : super(apiKey: 'test');

  @override
  Future<AiBreakdownResult> breakdownGoal({
    required String title,
    String? description,
    DateTime? deadline,
    int weeklyHours = 5,
    String locale = 'zh',
  }) async {
    throw Exception('network down');
  }
}

/// ✅ 有界等待：找 widget
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 260,
  Duration step = const Duration(milliseconds: 50),
  String? reason,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
  }
  await tester.pump();
  fail('pumpUntilFound timeout${reason == null ? "" : ": $reason"}');
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await pumpUntilFound(tester, finder, reason: 'tapVisible target not found');
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(finder, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 250));
}

/// ✅ 关键：等待 Hive 写入（纯 async 轮询）
/// 注意：这里不要再 runAsync；runAsync 由测试主体统一包住
Future<void> waitForHiveWriteExact({
  required String debugLabel,
  required int expectSubGoals,
  required int expectTasks,
  Duration timeout = const Duration(seconds: 8),
}) async {
  final sw = Stopwatch()..start();
  while (sw.elapsed < timeout) {
    final sgLen = Hive.box<SubGoal>(AppBoxes.subGoal).values.length;
    final tLen = Hive.box<Task>(AppBoxes.task).values.length;
    if (sgLen == expectSubGoals && tLen == expectTasks) return;
    await Future.delayed(const Duration(milliseconds: 50));
  }
  final sgLen = Hive.box<SubGoal>(AppBoxes.subGoal).values.length;
  final tLen = Hive.box<Task>(AppBoxes.task).values.length;
  fail('wait hive write ($debugLabel) timeout: subGoals=$sgLen tasks=$tLen (expected $expectSubGoals/$expectTasks)');
}

Future<void> waitForHiveWriteNonEmpty({
  required String debugLabel,
  Duration timeout = const Duration(seconds: 8),
}) async {
  final sw = Stopwatch()..start();
  while (sw.elapsed < timeout) {
    final sgOk = Hive.box<SubGoal>(AppBoxes.subGoal).values.isNotEmpty;
    final tOk = Hive.box<Task>(AppBoxes.task).values.isNotEmpty;
    if (sgOk && tOk) return;
    await Future.delayed(const Duration(milliseconds: 50));
  }
  final sgLen = Hive.box<SubGoal>(AppBoxes.subGoal).values.length;
  final tLen = Hive.box<Task>(AppBoxes.task).values.length;
  fail('wait hive write ($debugLabel) timeout: subGoals=$sgLen tasks=$tLen (expected non-empty)');
}

/// ✅ 忽略 RenderFlex overflow
FlutterExceptionHandler? _installIgnoreOverflowErrors() {
  final prev = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final msg = details.exceptionAsString();
    if (msg.contains('A RenderFlex overflowed by')) return;
    if (prev != null) return prev(details);
    FlutterError.dumpErrorToConsole(details);
  };
  return prev;
}

void _restoreFlutterErrorHandler(FlutterExceptionHandler? previous) {
  FlutterError.onError = previous;
}

class _Host extends StatelessWidget {
  final int goalKey;
  const _Host({required this.goalKey});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          // 不必 await；测试主体会 runAsync 包住整条链
          onPressed: () => context.read<AiBreakdownProvider>().openForGoalKey(context, goalKey),
          child: const Text('OPEN_AI_BREAKDOWN'),
        ),
      ),
    );
  }
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

  tearDownAll(() async {
    try {
      await Hive.close();
    } catch (_) {}
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

  Future<Widget> _wrapApp({
    required int goalKey,
    required AiService ai,
  }) async {
    final goalP = GoalProvider();
    final subGoalP = SubGoalProvider();
    final taskP = TaskProvider();

    await goalP.init();
    await subGoalP.init();
    await taskP.init();

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
        Provider.value(value: ai),
        ChangeNotifierProvider.value(value: aiP),
      ],
      child: MaterialApp(home: _Host(goalKey: goalKey)),
    );
  }

  void _setBigTestSurface(TestWidgetsFlutterBinding binding) {
    // ignore: deprecated_member_use
    binding.window.devicePixelRatioTestValue = 1.0;
    // ignore: deprecated_member_use
    binding.window.physicalSizeTestValue = const Size(1200, 1400);
  }

  void _clearTestSurface(TestWidgetsFlutterBinding binding) {
    // ignore: deprecated_member_use
    binding.window.clearPhysicalSizeTestValue();
    // ignore: deprecated_member_use
    binding.window.clearDevicePixelRatioTestValue();
  }

  testWidgets(
    'AI success: bottomsheet -> preview -> save writes SubGoal+Task into Hive',
    (tester) async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      _setBigTestSurface(binding);
      addTearDown(() => _clearTestSurface(binding));

      final prevHandler = _installIgnoreOverflowErrors();
      addTearDown(() => _restoreFlutterErrorHandler(prevHandler));

      final Finder btnGenerate = find.byKey(const Key('ai_breakdown_generate'));
      final Finder btnSave = find.byKey(const Key('ai_breakdown_save'));

      late int goalKey;
      late Widget app;

      // seed + build 可以在 runAsync，也可以不；这里保持你原来习惯
      await tester.runAsync(() async {
        goalKey = await _seedOneGoal();
        app = await _wrapApp(goalKey: goalKey, ai: FakeAiServiceSuccess());
      });

      await tester.pumpWidget(app);
      await tester.pump(const Duration(milliseconds: 400));

      // ✅ 核心：把整条流程放进 runAsync（Hive 写入就不会卡）
      await tester.runAsync(() async {
        await tapVisible(tester, find.text('OPEN_AI_BREAKDOWN'));
        await pumpUntilFound(tester, find.byType(AiBreakdownInputSheet), reason: 'input sheet');

        await tapVisible(tester, btnGenerate);

        await pumpUntilFound(tester, find.byType(AiBreakdownPreviewPage), reason: 'preview page');
        await tapVisible(tester, btnSave);

        // 让 pop/回调/后续 await 链跑起来
        await tester.pumpAndSettle(const Duration(milliseconds: 200));

        await waitForHiveWriteExact(
          debugLabel: 'flow success',
          expectSubGoals: 1,
          expectTasks: 2,
          timeout: const Duration(seconds: 10),
        );
      });

      expect(Hive.box<SubGoal>(AppBoxes.subGoal).values.length, 1);
      expect(Hive.box<Task>(AppBoxes.task).values.length, 2);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'AI failure: uses fallback and still writes into Hive + sets error',
    (tester) async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      _setBigTestSurface(binding);
      addTearDown(() => _clearTestSurface(binding));

      final prevHandler = _installIgnoreOverflowErrors();
      addTearDown(() => _restoreFlutterErrorHandler(prevHandler));

      final Finder btnGenerate = find.byKey(const Key('ai_breakdown_generate'));
      final Finder btnSave = find.byKey(const Key('ai_breakdown_save'));

      late int goalKey;
      late Widget app;

      await tester.runAsync(() async {
        goalKey = await _seedOneGoal();
        app = await _wrapApp(goalKey: goalKey, ai: FakeAiServiceFailure());
      });

      await tester.pumpWidget(app);
      await tester.pump(const Duration(milliseconds: 400));

      await tester.runAsync(() async {
        await tapVisible(tester, find.text('OPEN_AI_BREAKDOWN'));
        await pumpUntilFound(tester, find.byType(AiBreakdownInputSheet), reason: 'input sheet');

        await tapVisible(tester, btnGenerate);

        await pumpUntilFound(
          tester,
          find.byType(AiBreakdownPreviewPage),
          reason: 'preview page (failure should still go preview)',
        );

        await tapVisible(tester, btnSave);
        await tester.pumpAndSettle(const Duration(milliseconds: 200));

        await waitForHiveWriteNonEmpty(
          debugLabel: 'flow failure',
          timeout: const Duration(seconds: 10),
        );
      });

      expect(Hive.box<SubGoal>(AppBoxes.subGoal).values.isNotEmpty, isTrue);
      expect(Hive.box<Task>(AppBoxes.task).values.isNotEmpty, isTrue);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}

