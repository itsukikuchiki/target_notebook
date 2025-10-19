import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../adapters/dailylog_adapter.dart';
import '../widgets/charts/simple_bar_chart.dart';

class InsightPage extends StatelessWidget {
  const InsightPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DailyLogAdapter>().weeklyStats();

    // —— 零数据友好摘要（微抛光）——
    final totalHours = vm.hoursByDay.values.fold<double>(0, (a, b) => a + b);
    final friendlySummary = totalHours == 0
        ? '本周还没有记录投入时长，开始第一条吧！'
        : '本周累计 ${totalHours.toStringAsFixed(1)} 小时，完成率 ${(vm.completionRate * 100).toStringAsFixed(0)}%。';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('最近 7 天投入时长', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(height: 160, child: SimpleBarChart(data: vm.hoursByDay)),
          const SizedBox(height: 24),
          Text('本周完成率', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(value: vm.completionRate),
                    Center(child: Text('${(vm.completionRate * 100).toStringAsFixed(0)}%')),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  friendlySummary,
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

