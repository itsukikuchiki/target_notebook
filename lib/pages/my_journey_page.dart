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

/// 临时兼容：项目里当前没有暴露/不存在 GoalNodeVM 类型名，
/// 但本页的 weekly focus 需要一个“目标树节点”的列表类型。
/// 先用 dynamic 让工程编译通过；后续确认真实节点类型后可改为：
///   typedef GoalNodeVM = <真实类型>;
typedef GoalNodeVM = dynamic;

class MyJourneyPage extends StatefulWidget {
  const MyJourneyPage({super.key});

  @override
  State<MyJourneyPage> createState() => _MyJourneyPageState();
}

class _MyJourneyPageState extends State<MyJourneyPage> {
  final Set<int> _expandedGoalKeys = <int>{};
  final Set<int> _expandedSubGoalKeys = <int>{};

  DateTime _mondayOfWeek(DateTime d) {
    final x = DateTime(d.year, d.month, d.day);
    // DateTime.monday=1 ... sunday=7
    return x.subtract(Duration(days: x.weekday - DateTime.monday));
  }

  String _fmtYmd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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

    // =========================
    // W6：本周三目标（按 priority 取前三）
    // =========================
    final monday = _mondayOfWeek(DateTime.now());
    final focus = [...goals]
      ..sort((a, b) {
        // priority 越小越优先
        final pa = a.goal.priority;
        final pb = b.goal.priority;
        if (pa != pb) return pa.compareTo(pb);
        // 同优先度就按 key 稳定
        return a.goalKey.compareTo(b.goalKey);
      });
    final top3Goals = focus.take(3).toList();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: goals.length + 1, // +1 for weekly focus card
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        // 顶部插入：本周三目标卡片
        if (i == 0) {
          return _WeeklyFocusCard(
            monday: monday,
            items: top3Goals,
            onTapGoal: (goalKey) {
              // 体验：点一下展开该目标
              setState(() {
                if (_expandedGoalKeys.contains(goalKey)) {
                  _expandedGoalKeys.remove(goalKey);
                } else {
                  _expandedGoalKeys.add(goalKey);
                }
              });
            },
            fmtYmd: _fmtYmd,
          );
        }

        // 下面才是原 goals 列表
        final node = goals[i - 1];
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
                                await ctx
                                    .read<AiBreakdownProvider>()
                                    .openForGoalKey(ctx, goalKey);
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
              ],
            ],
          ),
        );
      },
    );
  }
}

class _WeeklyFocusCard extends StatelessWidget {
  final DateTime monday;
  final List<GoalNodeVM> items;
  final void Function(int goalKey) onTapGoal;
  final String Function(DateTime d) fmtYmd;

  const _WeeklyFocusCard({
    required this.monday,
    required this.items,
    required this.onTapGoal,
    required this.fmtYmd,
  });

  @override
  Widget build(BuildContext context) {
    final end = monday.add(const Duration(days: 6));

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.55),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star, size: 18),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    '本周三目标',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${fmtYmd(monday)} ~ ${fmtYmd(end)}',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Text(
                '还没有目标。先创建一个目标并设置优先度（P1 最高）。',
                style: TextStyle(color: Colors.black54),
              )
            else
              Column(
                children: [
                  for (int i = 0; i < items.length; i++)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: items[i].color.withOpacity(0.15),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            color: items[i].color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(
                        items[i].goal.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'P${items[i].goal.priority} · 进度 ${(items[i].progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => onTapGoal(items[i].goalKey),
                    ),
                ],
              ),
            const SizedBox(height: 2),
            const Text(
              '规则：周一自动刷新（按目标优先度选前三）。点击可快速展开目标树。',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
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

