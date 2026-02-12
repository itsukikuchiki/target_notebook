// lib/services/local_fallback_breakdown.dart
import '../models/ai_breakdown_models.dart';

class LocalFallbackBreakdown {
  static AiBreakdownResult build(String goalTitle) {
    return AiBreakdownResult(subGoals: [
      AiSubGoalDraft(
        title: '定义完成标准',
        why: '避免目标模糊导致返工',
        estimateDays: 2,
        priority: 1,
        tasks: [
          AiTaskDraft(title: '写下完成标准（3条）', minutes: 30, dueInDays: 0, priority: 1),
          AiTaskDraft(title: '列出资源与限制', minutes: 30, dueInDays: 1, priority: 2),
        ],
      ),
      AiSubGoalDraft(
        title: '拆解里程碑',
        why: '把大目标变成可执行步骤',
        estimateDays: 7,
        priority: 2,
        tasks: [
          AiTaskDraft(title: '列出本周 3 个里程碑', minutes: 45, dueInDays: 0, priority: 1),
          AiTaskDraft(title: '为每个里程碑写下第一步', minutes: 45, dueInDays: 1, priority: 1),
        ],
      ),
      AiSubGoalDraft(
        title: '建立复盘机制',
        why: '持续迭代执行策略',
        estimateDays: 7,
        priority: 3,
        tasks: [
          AiTaskDraft(title: '安排每周复盘 15 分钟', minutes: 15, dueInDays: 3, priority: 3),
        ],
      ),
    ]);
  }
}

