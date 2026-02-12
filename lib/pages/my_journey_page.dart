// lib/pages/my_journey_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../adapters/goal_tree_adapter.dart';
import '../models/sub_goal.dart';
import '../models/task.dart';
import '../providers/ai_breakdown_provider.dart';

import 'editors/goal_edit_page.dart';
import 'editors/subgoal_edit_page.dart';
import 'editors/task_edit_page.dart';

class MyJourneyPage extends StatefulWidget {
  const MyJourneyPage({super.key});

  @override
  State<MyJourneyPage> createState() => _MyJourneyPageState();
}

class _MyJourneyPageState extends State<MyJourneyPage> {
  final Set<int> _expandedGoalKeys = <int>{};
  final Set<int> _expandedSubGoalKeys = <int>{};

  @override
  Widget build(BuildContext context) {
    final tree = context.watch<GoalTreeAdapter>();
    final goals = tree.goals;

    if (goals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.flag_circle_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
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
      itemCount: goals.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final node = goals[i];
        final goalKey = node.goalKey;
        final g = node.goal;
        final goalColor = node.color;

        final isExpanded = _expandedGoalKeys.contains(goalKey);

        return Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          child: Column(
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    isExpanded
                        ? _expandedGoalKeys.remove(goalKey)
                        : _expandedGoalKeys.add(goalKey);
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: goalColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              g.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                          ),

                          /// 右上角菜单：加入「AI 目标分解」入口
                          PopupMenuButton<String>(
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                key: Key('menu_ai_breakdown'),
                                value: 'ai_breakdown',
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(Icons.auto_awesome),
                                  title: Text('AI 目标分解'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'edit_goal',
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(Icons.edit),
                                  title: Text('编辑目标'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'add_subgoal',
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(Icons.subdirectory_arrow_right),
                                  title: Text('新增子目标'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'add_task',
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(Icons.task_alt),
                                  title: Text('新增任务'),
                                ),
                              ),
                            ],
                            onSelected: (v) async {
                              if (v == 'ai_breakdown') {
                                await ctx.read<AiBreakdownProvider>().openForGoalKey(ctx, goalKey);
                                return;
                              }
                              if (v == 'edit_goal') {
                                Navigator.of(ctx).pushNamed(
                                  GoalEditPage.route,
                                  arguments: goalKey,
                                );
                                return;
                              }
                              if (v == 'add_subgoal') {
                                Navigator.of(ctx).pushNamed(
                                  SubGoalEditPage.route,
                                  arguments: SubGoalEditArgs(goalId: goalKey),
                                );
                                return;
                              }
                              if (v == 'add_task') {
                                Navigator.of(ctx).pushNamed(
                                  TaskEditPage.route,
                                  arguments: {'goalId': goalKey},
                                );
                                return;
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: node.progress),
                      const SizedBox(height: 8),
                      Text(
                        'Tasks: ${node.doneTasks}/${node.totalTasks} · '
                        '进度 ${(node.progress * 100).toStringAsFixed(0)}% · '
                        'P${g.priority}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (isExpanded) ...[
                const Divider(height: 1),

                if (node.subGoals.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Column(
                      children: node.subGoals.map((sg) {
                        final expanded = _expandedSubGoalKeys.contains(sg.subGoalKey);

                        return _SubGoalTile(
                          subGoal: sg.subGoal,
                          subGoalKey: sg.subGoalKey,
                          goalColor: sg.color,
                          expanded: expanded,
                          tasks: sg.tasks,
                          onToggle: (k, e) {
                            setState(() {
                              e ? _expandedSubGoalKeys.add(k) : _expandedSubGoalKeys.remove(k);
                            });
                          },
                          onEdit: () {
                            Navigator.of(ctx).pushNamed(
                              SubGoalEditPage.route,
                              arguments: SubGoalEditArgs(
                                goalId: goalKey,
                                subGoalKey: sg.subGoalKey,
                              ),
                            );
                          },
                          onAddTask: () {
                            Navigator.of(ctx).pushNamed(
                              TaskEditPage.route,
                              arguments: {
                                'goalId': goalKey,
                                'subGoalId': sg.subGoalKey,
                              },
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: _DirectTasksSection(
                    goalColor: goalColor,
                    tasks: node.directTasks,
                    onAddTask: () {
                      Navigator.of(ctx).pushNamed(
                        TaskEditPage.route,
                        arguments: {'goalId': goalKey},
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SubGoalTile extends StatelessWidget {
  final SubGoal subGoal;
  final int subGoalKey;
  final Color goalColor;
  final bool expanded;
  final List<Task> tasks;

  final void Function(int subGoalKey, bool expanded) onToggle;
  final VoidCallback onEdit;
  final VoidCallback onAddTask;

  const _SubGoalTile({
    required this.subGoal,
    required this.subGoalKey,
    required this.goalColor,
    required this.expanded,
    required this.tasks,
    required this.onToggle,
    required this.onEdit,
    required this.onAddTask,
  });

  @override
  Widget build(BuildContext context) {
    final title = subGoal.title;
    final priority = subGoal.priority;

    final doneCount = tasks.where((t) => t.done == true).length;
    final total = tasks.length;
    final progress = total == 0 ? 0.0 : doneCount / total;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
      child: Column(
        children: [
          InkWell(
            onTap: () => onToggle(subGoalKey, !expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: goalColor.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$title  ·  P$priority',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 18),
                    tooltip: '编辑子目标',
                  ),
                  IconButton(
                    onPressed: onAddTask,
                    icon: const Icon(Icons.add_task, size: 18),
                    tooltip: '新增任务',
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Column(
              children: [
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 6),
                Text(
                  'Tasks: $doneCount/$total · ${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            if (tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '暂无任务',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
                child: Column(
                  children: tasks.map((t) => _TaskRow(task: t, color: goalColor)).toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _DirectTasksSection extends StatelessWidget {
  final Color goalColor;
  final List<Task> tasks;
  final VoidCallback onAddTask;

  const _DirectTasksSection({
    required this.goalColor,
    required this.tasks,
    required this.onAddTask,
  });

  @override
  Widget build(BuildContext context) {
    final doneCount = tasks.where((t) => t.done == true).length;
    final total = tasks.length;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '直接任务',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '$doneCount/$total',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: onAddTask,
                  icon: const Icon(Icons.add_task, size: 18),
                  tooltip: '新增任务',
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (tasks.isEmpty)
              const Text('暂无任务', style: TextStyle(color: Colors.black54))
            else
              Column(
                children: tasks.map((t) => _TaskRow(task: t, color: goalColor)).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final Task task;
  final Color color;

  const _TaskRow({required this.task, required this.color});

  @override
  Widget build(BuildContext context) {
    final done = task.done == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: done ? color.withOpacity(0.9) : Colors.black38,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                decoration: done ? TextDecoration.lineThrough : null,
                color: done ? Colors.black45 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

