import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../adapters/goal_adapter.dart';
import 'editors/goal_edit_page.dart';
import 'editors/subgoal_edit_page.dart';
import 'editors/task_edit_page.dart';

class MyJourneyPage extends StatelessWidget {
  const MyJourneyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final goals = context.select((GoalAdapter p) => p.goalsVM);

    if (goals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.flag_circle_outlined,
                  size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              const Text(
                '还没有目标，点右下角＋添加一个吧',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (ctx, i) {
        final g = goals[i];
        return _GoalCard(
          title: g.title,
          progress: g.progress,
          doneCount: g.doneCount,
          totalCount: g.tasksCount,
          onTap: () {
            // 占位演示：进入目标编辑
            Navigator.of(ctx).pushNamed(GoalEditPage.route);
          },
          onAddSubgoal: () {
            Navigator.of(ctx).pushNamed(SubGoalEditPage.route);
          },
          onAddTask: () {
            Navigator.of(ctx).pushNamed(TaskEditPage.route);
          },
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: goals.length,
    );
  }
}

class _GoalCard extends StatelessWidget {
  final String title;
  final double progress; // 0..1
  final int doneCount;
  final int totalCount;
  final VoidCallback onTap;
  final VoidCallback onAddSubgoal;
  final VoidCallback onAddTask;

  const _GoalCard({
    required this.title,
    required this.progress,
    required this.doneCount,
    required this.totalCount,
    required this.onTap,
    required this.onAddSubgoal,
    required this.onAddTask,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: cs.surfaceVariant.withOpacity(0.5),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题 + 溢出菜单
              Row(
                children: [
                  const Icon(Icons.flag, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: '更多',
                    itemBuilder: (c) => [
                      const PopupMenuItem(
                        value: 'add_subgoal',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.subdirectory_arrow_right),
                          title: Text('新增子目标'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'add_task',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.task_alt),
                          title: Text('新增任务'),
                        ),
                      ),
                    ],
                    onSelected: (v) {
                      switch (v) {
                        case 'add_subgoal':
                          onAddSubgoal();
                          break;
                        case 'add_task':
                          onAddTask();
                          break;
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 进度条
              LinearProgressIndicator(value: progress.clamp(0, 1)),
              const SizedBox(height: 8),

              // 统计
              Text(
                'Tasks: $doneCount/$totalCount · 进度 ${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

