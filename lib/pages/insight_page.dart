import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../adapters/dailylog_adapter.dart';
import '../adapters/goal_tree_adapter.dart';

class InsightPage extends StatelessWidget {
  const InsightPage({super.key});

  @override
  Widget build(BuildContext context) {
    // ===== 本周投入（已有） =====
    final dailyAdapter = context.watch<DailyLogAdapter>();
    final weekly = dailyAdapter.weeklyStats();

    final totalHours =
        weekly.hoursByDay.values.fold<double>(0.0, (a, b) => a + b);

    final desc = weekly.message.isNotEmpty
        ? weekly.message
        : '本周累计 ${totalHours.toStringAsFixed(1)} 小时，完成率 ${(weekly.completionRate * 100).toStringAsFixed(0)}%。';

    // ===== 目标推进（新增） =====
    final goalTree = context.watch<GoalTreeAdapter>();

    return Scaffold(
      appBar: AppBar(title: const Text('Insight')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // =========================
          // 本周投入
          // =========================
          Text(desc, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: weekly.completionRate.clamp(0.0, 1.0),
            minHeight: 8,
          ),
          const SizedBox(height: 16),
          _WeekBars(hoursByDay: weekly.hoursByDay),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),

          // =========================
          // 目标推进（12/15）
          // =========================
          Text(
            '目标推进',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),

          if (goalTree.tree.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  '暂无目标数据',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            )
          else
            ...goalTree.tree.map(
              (node) => _GoalProgressCard(node: node),
            ),
        ],
      ),
    );
  }
}

// ==========================
// Goal Progress Card（占位版）
// ==========================

class _GoalProgressCard extends StatelessWidget {
  final GoalNode node;

  const _GoalProgressCard({required this.node});

  @override
  Widget build(BuildContext context) {
    final progress = node.progress.clamp(0.0, 1.0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Color(node.color),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    node.goal.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // 进度条（后面换 BurnupChart）
            LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: Color(node.color),
              backgroundColor:
                  Theme.of(context).dividerColor.withOpacity(0.3),
            ),

            const SizedBox(height: 6),
            Text(
              '${node.doneTasks}/${node.totalTasks} 已完成',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================
// 周柱状图（原封不动）
// ==========================

class _WeekBars extends StatelessWidget {
  final Map<DateTime, double> hoursByDay;
  const _WeekBars({required this.hoursByDay});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
    DateTime _weekStart(DateTime d) {
      final date = _dateOnly(d);
      final delta = (date.weekday + 6) % 7;
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
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.85),
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

