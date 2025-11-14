import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../adapters/dailylog_adapter.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Insight')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(desc, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: vm.completionRate.clamp(0.0, 1.0),
              minHeight: 8,
            ),
            const SizedBox(height: 16),
            _WeekBars(hoursByDay: vm.hoursByDay),
          ],
        ),
      ),
    );
  }
}

class _WeekBars extends StatelessWidget {
  final Map<DateTime, double> hoursByDay;
  const _WeekBars({required this.hoursByDay});

  @override
  Widget build(BuildContext context) {
    // 为保证有序：取当前周一开始的 7 天顺序展示
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
                    height: 8 + 72 * ((hoursByDay[_dateOnly(d)] ?? 0.0) / (maxVal == 0 ? 1 : maxVal)),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ['一','二','三','四','五','六','日'][d.weekday - 1],
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

