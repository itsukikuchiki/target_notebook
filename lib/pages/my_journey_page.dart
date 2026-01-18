import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../adapters/goal_tree_adapter.dart';
import '../models/task.dart';

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
              Icon(Icons.flag_circle_outlined,
                  size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              const Text('还没有目标，点右下角＋添加一个吧',
                  style: TextStyle(color: Colors.grey)),
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
                      Row(children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: goalColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(g.title,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                        ),
                        Icon(isExpanded
                            ? Icons.expand_less
                            : Icons.expand_more),
                        PopupMenuButton<String>(
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'edit_goal',
                                child: ListTile(
                                    dense: true,
                                    leading: Icon(Icons.edit),
                                    title: Text('编辑目标'))),
                            PopupMenuItem(
                                value: 'add_subgoal',
                                child: ListTile(
                                    dense: true,
                                    leading: Icon(Icons.subdirectory_arrow_right),
                                    title: Text('新增子目标'))),
                            PopupMenuItem(
                                value: 'add_task',
                                child: ListTile(
                                    dense: true,
                                    leading: Icon(Icons.task_alt),
                                    title: Text('新增任务'))),
                          ],
                          onSelected: (v) {
                            if (v == 'edit_goal') {
                              Navigator.of(ctx).pushNamed(
                                  GoalEditPage.route,
                                  arguments: goalKey);
                            } else if (v == 'add_subgoal') {
                              Navigator.of(ctx).pushNamed(
                                SubGoalEditPage.route,
                                arguments:
                                    SubGoalEditArgs(goalId: goalKey),
                              );
                            } else if (v == 'add_task') {
                              Navigator.of(ctx).pushNamed(
                                TaskEditPage.route,
                                arguments: {'goalId': goalKey},
                              );
                            }
                          },
                        )
                      ]),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: node.progress),
                      const SizedBox(height: 8),
                      Text(
                        'Tasks: ${node.doneTasks}/${node.totalTasks} · '
                        '进度 ${(node.progress * 100).toStringAsFixed(0)}% · '
                        'P${g.priority}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
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
                        final expanded =
                            _expandedSubGoalKeys.contains(sg.subGoalKey);
                        return _SubGoalTile(
                          subGoal: sg.subGoal,
                          subGoalKey: sg.subGoalKey,
                          goalColor: sg.color,
                          expanded: expanded,
                          tasks: sg.tasks,
                          onToggle: (k, e) {
                            setState(() {
                              e
                                  ? _expandedSubGoalKeys.add(k)
                                  : _expandedSubGoalKeys.remove(k);
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
              ]
            ],
          ),
        );
      },
    );
  }
}

