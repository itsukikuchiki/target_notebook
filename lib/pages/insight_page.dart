import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../adapters/dailylog_adapter.dart';
import '../adapters/goal_tree_adapter.dart';
import '../providers/nav_provider.dart';

class InsightPage extends StatelessWidget {
  const InsightPage({super.key});

  @override
  Widget build(BuildContext context) {
    final adapter = context.watch<DailyLogAdapter>();
    final vm = adapter.weeklyStats();

    final totalHours = vm.hoursByDay.values.fold<double>(0.0, (a, b) => a + b);
    final desc = vm.message.isNotEmpty
        ? vm.message
        : '本周累计 ${totalHours.toStringAsFixed(1)} 小时，完成率 ${(vm.completionRate * 100).toStringAsFixed(0)}%。';

    final goalTree = context.watch<GoalTreeAdapter>();
    final goals = goalTree.goals;

    return Scaffold(
      appBar: AppBar(title: const Text('Insight')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(desc, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: vm.completionRate.clamp(0.0, 1.0),
              minHeight: 8,
            ),

            // ✅ W6：闭环行动栏（切换 BottomNav 的 tab）
            const SizedBox(height: 12),
            _LoopActionBar(
              onGoJourney: () => context.read<NavProvider>().setIndex(0),
              onGoDaily: () => context.read<NavProvider>().setIndex(1),
              onGoReflection: () => context.read<NavProvider>().setIndex(3),
            ),

            const SizedBox(height: 16),
            _WeekBars(hoursByDay: vm.hoursByDay),

            const SizedBox(height: 24),
            Row(
              children: [
                const Text(
                  'Goals · Burndown / Burnup（MVP）',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  '快照',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (goals.isEmpty)
              const Text(
                '还没有目标。去 My Journey 新建一个目标吧。',
                style: TextStyle(color: Colors.black54),
              )
            else
              ...goals.map((g) => _GoalBurnCard(node: g)),
          ],
        ),
      ),
    );
  }
}

class _LoopActionBar extends StatelessWidget {
  final VoidCallback onGoJourney;
  final VoidCallback onGoDaily;
  final VoidCallback onGoReflection;

  const _LoopActionBar({
    required this.onGoJourney,
    required this.onGoDaily,
    required this.onGoReflection,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.45),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '闭环行动',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onGoJourney,
                    icon: const Icon(Icons.flag),
                    label: const Text('看目标'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onGoDaily,
                    icon: const Icon(Icons.today),
                    label: const Text('去执行'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onGoReflection,
                    icon: const Icon(Icons.notes),
                    label: const Text('去复盘'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '流程：目标（拆解）→ 日程（执行）→ Insight（检查）→ Reflection（复盘）。',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalBurnCard extends StatelessWidget {
  final GoalNode node;
  const _GoalBurnCard({required this.node});

  @override
  Widget build(BuildContext context) {
    final total = node.totalTasks;
    final done = node.doneTasks;
    final remain = (total - done).clamp(0, 1 << 30);
    final progress = node.progress.clamp(0.0, 1.0);

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.45),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: node.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    node.goal.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'P${node.goal.priority}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 10),

            LinearProgressIndicator(value: progress, minHeight: 8),
            const SizedBox(height: 8),
            Text(
              'Done $done / $total · Remaining $remain',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _MiniBar(
                    label: 'Burnup（完成）',
                    value: done,
                    total: total == 0 ? 1 : total,
                    color: node.color,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniBar(
                    label: 'Burndown（剩余）',
                    value: remain,
                    total: total == 0 ? 1 : total,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Text(
              '注：当前为“快照版”（未记录完成时间，无法画历史曲线）。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;

  const _MiniBar({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: Theme.of(context).colorScheme.surface,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text('$value', style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _WeekBars extends StatelessWidget {
  final Map<DateTime, double> hoursByDay;
  const _WeekBars({required this.hoursByDay});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

    DateTime _weekStart(DateTime d) {
      final date = _dateOnly(d);
      final delta = (date.weekday + 6) % 7; // Monday start
      return date.subtract(Duration(days: delta));
    }

    final start = _weekStart(now);
    final days = List.generate(7, (i) => start.add(Duration(days: i)));

    final maxVal = (hoursByDay.values.isEmpty)
        ? 1.0
        : hoursByDay.values.fold<double>(0.0, (a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final d in days)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (hoursByDay[_dateOnly(d)] ?? 0.0).toStringAsFixed(1),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 8 +
                        72 *
                            ((hoursByDay[_dateOnly(d)] ?? 0.0) /
                                (maxVal == 0 ? 1 : maxVal)),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ['一', '二', '三', '四', '五', '六', '日'][d.weekday - 1],
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

