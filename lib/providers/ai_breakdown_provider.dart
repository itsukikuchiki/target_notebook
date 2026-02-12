// lib/providers/ai_breakdown_provider.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../core/hive_init.dart'; // AppBoxes
import '../models/goal.dart';
import '../models/sub_goal.dart';
import '../models/task.dart';
import '../models/ai_breakdown_models.dart';

import '../services/ai_service.dart';
import '../services/local_fallback_breakdown.dart';

import '../pages/ai_breakdown/ai_breakdown_input_sheet.dart';
import '../pages/ai_breakdown/ai_breakdown_preview_page.dart';

import 'goal_provider.dart';
import 'sub_goal_provider.dart';
import 'task_provider.dart';

class AiBreakdownProvider extends ChangeNotifier {
  final AiService ai;
  final GoalProvider goalProvider;
  final SubGoalProvider subGoalProvider;
  final TaskProvider taskProvider;

  bool loading = false;
  String? error;

  AiBreakdownProvider({
    required this.ai,
    required this.goalProvider,
    required this.subGoalProvider,
    required this.taskProvider,
  });

  Future<void> openForGoalKey(BuildContext context, int goalKey) async {
    final goal = _getGoalByKey(goalKey);
    if (goal == null) {
      _toastIfMounted(context, '找不到目标（key=$goalKey）');
      return;
    }

    // 1) 输入参数
    final input = await showModalBottomSheet<AiBreakdownInput>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AiBreakdownInputSheet(goal: goal),
    );
    if (input == null) return;

    // 2) AI / fallback
    loading = true;
    error = null;
    notifyListeners();

    AiBreakdownResult result;
    try {
      result = await ai.breakdownGoal(
        title: goal.title,
        description: input.description,
        deadline: input.deadline,
        weeklyHours: input.weeklyHours,
        locale: 'zh',
      );
      if (result.subGoals.isEmpty) {
        result = LocalFallbackBreakdown.build(goal.title);
      }
    } catch (e) {
      error = e.toString();
      result = LocalFallbackBreakdown.build(goal.title);
    }

    loading = false;
    notifyListeners();

    // 3) 预览/编辑
    final edited = await Navigator.of(context).push<AiBreakdownResult>(
      MaterialPageRoute(
        builder: (_) => AiBreakdownPreviewPage(initial: result),
      ),
    );
    if (edited == null) return;

    if (edited.subGoals.isEmpty) {
      _toastIfMounted(context, '没有可保存的子目标（为空）');
      return;
    }

    // 4) 落库
    final wrote = await _applyToHive(
      goalKey: goalKey,
      goal: goal,
      breakdown: edited,
    );

    if (!wrote) {
      _toastIfMounted(context, '写入失败，请稍后重试');
      return;
    }

    // 5) 刷新
    await subGoalProvider.init();
    await taskProvider.init();
    await goalProvider.init();

    notifyListeners();
    _toastIfMounted(context, 'AI 分解已写入目标树');
  }

  Goal? _getGoalByKey(int goalKey) {
    try {
      return Hive.box<Goal>(AppBoxes.goal).get(goalKey);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _applyToHive({
    required int goalKey,
    required Goal goal,
    required AiBreakdownResult breakdown,
  }) async {
    try {
      final subGoalBox = Hive.box<SubGoal>(AppBoxes.subGoal);
      final taskBox = Hive.box<Task>(AppBoxes.task);

      debugPrint(
        '[AiBreakdownProvider] BEFORE write: subGoals=${subGoalBox.values.length}, tasks=${taskBox.values.length}, taskBoxOpen=${taskBox.isOpen}',
      );

      // orderIndex 起点
      final existing = subGoalProvider.subGoalsByGoal(goalKey);
      int nextOrder = 0;
      for (final sg in existing) {
        if (sg.orderIndex >= nextOrder) nextOrder = sg.orderIndex + 1;
      }

      final baseColor = goal.color;

      for (final sgDraft in breakdown.subGoals) {
        final subGoal = SubGoal(
          goalId: goalKey,
          title: sgDraft.title.trim().isEmpty ? '子目标' : sgDraft.title.trim(),
          description: (sgDraft.description?.trim().isNotEmpty == true)
              ? sgDraft.description!.trim()
              : (sgDraft.why?.trim().isNotEmpty == true ? sgDraft.why!.trim() : null),
          orderIndex: nextOrder++,
          priority: sgDraft.priority.clamp(1, 5),
          color: baseColor,
        );

        final subGoalKey = await subGoalProvider.addSubGoal(subGoal);

        debugPrint(
          '[AiBreakdownProvider] subGoal added key=$subGoalKey title="${subGoal.title}" tasks=${sgDraft.tasks.length}',
        );

        // ✅ 一次性写入 tasks（避免逐条 await 卡住）
        final toAdd = <Task>[];
        for (final tDraft in sgDraft.tasks) {
          final due = DateTime.now().add(Duration(days: tDraft.dueInDays));

          final startAt = DateTime(due.year, due.month, due.day, 9, 0);
          final deadline = DateTime(due.year, due.month, due.day, 23, 59, 59);

          toAdd.add(
            Task(
              title: tDraft.title.trim().isEmpty ? '任务' : tDraft.title.trim(),
              note: tDraft.note?.trim().isNotEmpty == true ? tDraft.note!.trim() : null,
              goalId: goalKey,
              subGoalId: subGoalKey,
              startAt: startAt,
              deadline: deadline,
              done: false,
              isTodayTop3: false,
              priority: tDraft.priority.clamp(1, 5),
              completion: 0.0,
              color: baseColor,
            ),
          );
        }

        if (toAdd.isNotEmpty) {
          debugPrint(
            '[AiBreakdownProvider] task write begin: addAll(${toAdd.length}) taskBoxLen(before)=${taskBox.values.length}',
          );

          await taskBox.addAll(toAdd);
          await taskBox.flush(); // ✅ 强制落盘/提交，测试里更稳定

          debugPrint(
            '[AiBreakdownProvider] task write done: taskBoxLen(after)=${taskBox.values.length}',
          );
        }
      }

      debugPrint(
        '[AiBreakdownProvider] AFTER write: subGoals=${subGoalBox.values.length}, tasks=${taskBox.values.length}',
      );

      return true;
    } catch (e, st) {
      debugPrint('[AiBreakdownProvider] APPLY FAILED: $e\n$st');
      return false;
    }
  }

  void _toastIfMounted(BuildContext context, String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}

