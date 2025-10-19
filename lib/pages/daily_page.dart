// lib/pages/daily_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../adapters/task_adapter.dart';

class DailyPage extends StatefulWidget {
  const DailyPage({super.key});

  @override
  State<DailyPage> createState() => _DailyPageState();
}

class _DailyPageState extends State<DailyPage> {
  DateTime _focused = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final day = DateUtils.dateOnly(_focused);
    final tasks = context.select((TaskAdapter p) => p.tasksForDate(day));

    return Column(
      children: [
        // ===== 顶部日期条 =====
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: '前一天',
                onPressed: () => setState(
                  () => _focused = _focused.subtract(const Duration(days: 1)),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    DateFormat('yyyy-MM-dd (EEE)').format(_focused),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: '后一天',
                onPressed: () =>
                    setState(() => _focused = _focused.add(const Duration(days: 1))),
              ),
            ],
          ),
        ),

        // ===== 内容区 =====
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: tasks.isEmpty
                ? const Center(
                    key: ValueKey('empty'),
                    child: Text(
                      '今日还没有任务，点右下角＋添加一个',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    key: const ValueKey('list'),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemBuilder: (ctx, i) {
                      final t = tasks[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        elevation: 0,
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceVariant
                            .withOpacity(0.5),
                        child: CheckboxListTile(
                          value: t.done,
                          onChanged: (v) => context
                              .read<TaskAdapter>()
                              .toggleTaskDone(t.id, v ?? false),
                          title: Text(
                            t.title,
                            style: TextStyle(
                              decoration: t.done
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          secondary: const Icon(Icons.task_alt_outlined),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 2),
                    itemCount: tasks.length,
                  ),
          ),
        ),
      ],
    );
  }
}

