import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

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

import '../helpers/hive_test_env.dart';
import '../fakes/fake_notification_local_service.dart';

class FakeAiServiceSuccess extends AiService {
  FakeAiServiceSuccess() : super(apiKey: 'fake');

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
        title: '子目标A',
        description: 'descA',
        estimateDays: 3,
        priority: 1,
        tasks: [
          AiTaskDraft(title: '任务A1', minutes: 45, dueInDays: 0, priority: 1, note: 'n1'),
          AiTaskDraft(title: '任务A2', minutes: 30, dueInDays: 2, priority: 3),
        ],
      ),
      AiSubGoalDraft(
        title: '子目标B',
        why: 'whyB',
        estimateDays: 5,
        priority: 2,
        tasks: [
          AiTaskDraft(title: '任务B1', minutes: 60, dueInDays: 1, priority: 2),
        ],
      ),
    ]);
  }
}

class FakeAiServiceThrows extends AiService {
  FakeAiServiceThrows() : super(apiKey: 'fake');

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

class FakeAiServiceReturnsEmpty extends AiService {
  FakeAiServiceReturnsEmpty() : super(apiKey: 'fake');

  @override
  Future<AiBreakdownResult> breakdownGoal({
    required String title,
    String? description,
    DateTime? deadline,
    int weeklyHours = 5,
    String locale = 'zh',
  }) async {
    // ✅ AiBreakdownResult 不是 const 构造，不能写 const
    return AiBreakdownResult(subGoals: []);
  }
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

  Future<AiBreakdownProvider> _makeProvider({required AiService ai}) async {
    final goalP = GoalProvider();
    final subGoalP = SubGoalProvider();
    final taskP = TaskProvider();

    await goalP.init();
    await subGoalP.init();
    await taskP.init(
      taskBox: Hive.box<Task>(AppBoxes.task),
      notification: FakeNotificationLocalService(),
    );

    return AiBreakdownProvider(
      ai: ai,
      goalProvider: goalP,
      subGoalProvider: subGoalP,
      taskProvider: taskP,
    );
  }

  test(
    'AI breakdown flow writes SubGoals & Tasks into Hive (success path)',
    () async {
      final goalBox = Hive.box<Goal>(AppBoxes.goal);
      final goalKey = await goalBox.add(
        Goal(title: '通过 FP2', description: '两个月内通过', priority: 1, color: 0xFF5C6BC0),
      );

      final aiP = await _makeProvider(ai: FakeAiServiceSuccess());

      final ok = await aiP.runBreakdownForGoalKey(
        goalKey: goalKey,
        input: const AiBreakdownRunInput(description: 'test', weeklyHours: 5),
      );
      expect(ok, isTrue);

      final subBox = Hive.box<SubGoal>(AppBoxes.subGoal);
      final taskBox = Hive.box<Task>(AppBoxes.task);

      expect(subBox.values.length, 2);
      expect(taskBox.values.length, 3);
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );

  test(
    'AI breakdown flow falls back to LocalFallbackBreakdown when AI throws',
    () async {
      final goalBox = Hive.box<Goal>(AppBoxes.goal);
      final goalKey = await goalBox.add(
        Goal(title: '目标X', description: 'desc', priority: 2, color: 0xFFEF5350),
      );

      final aiP = await _makeProvider(ai: FakeAiServiceThrows());

      final ok = await aiP.runBreakdownForGoalKey(
        goalKey: goalKey,
        input: const AiBreakdownRunInput(description: 'test'),
      );
      expect(ok, isTrue);

      final subBox = Hive.box<SubGoal>(AppBoxes.subGoal);
      final taskBox = Hive.box<Task>(AppBoxes.task);

      expect(subBox.values.isNotEmpty, isTrue);
      expect(taskBox.values.isNotEmpty, isTrue);
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );

  test(
    'AI breakdown flow falls back when AI returns empty subGoals',
    () async {
      final goalBox = Hive.box<Goal>(AppBoxes.goal);
      final goalKey = await goalBox.add(
        Goal(title: '目标Y', description: 'desc', priority: 2, color: 0xFF42A5F5),
      );

      final aiP = await _makeProvider(ai: FakeAiServiceReturnsEmpty());

      final ok = await aiP.runBreakdownForGoalKey(
        goalKey: goalKey,
        input: const AiBreakdownRunInput(description: 'test'),
      );
      expect(ok, isTrue);

      final subBox = Hive.box<SubGoal>(AppBoxes.subGoal);
      final taskBox = Hive.box<Task>(AppBoxes.task);

      expect(subBox.values.isNotEmpty, isTrue);
      expect(taskBox.values.isNotEmpty, isTrue);
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );

  test(
    'runBreakdownForGoalKey returns false when goalKey not found',
    () async {
      final aiP = await _makeProvider(ai: FakeAiServiceSuccess());

      final ok = await aiP.runBreakdownForGoalKey(
        goalKey: 999999,
        input: const AiBreakdownRunInput(description: 'test'),
      );
      expect(ok, isFalse);

      expect(Hive.box<SubGoal>(AppBoxes.subGoal).values.length, 0);
      expect(Hive.box<Task>(AppBoxes.task).values.length, 0);
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );

  test(
    'runBreakdownForGoalKey returns false when editedOverride has empty subGoals',
    () async {
      final goalBox = Hive.box<Goal>(AppBoxes.goal);
      final goalKey = await goalBox.add(
        Goal(title: '目标Z', description: 'desc', priority: 2, color: 0xFF66BB6A),
      );

      final aiP = await _makeProvider(ai: FakeAiServiceSuccess());

      final ok = await aiP.runBreakdownForGoalKey(
        goalKey: goalKey,
        input: const AiBreakdownRunInput(description: 'test'),
        // ✅ 这里也不能 const
        editedOverride: AiBreakdownResult(subGoals: []),
      );
      expect(ok, isFalse);

      expect(Hive.box<SubGoal>(AppBoxes.subGoal).values.length, 0);
      expect(Hive.box<Task>(AppBoxes.task).values.length, 0);
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );
}
