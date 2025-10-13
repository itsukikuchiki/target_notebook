import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../demo/seed_demo.dart';
import '../../../providers/goal_provider.dart';
import '../../../providers/task_provider.dart';
import '../../../models/goal.dart';

class JourneyDemoPage extends StatefulWidget {
  const JourneyDemoPage({super.key});
  @override
  State<JourneyDemoPage> createState() => _JourneyDemoPageState();
}

class _JourneyDemoPageState extends State<JourneyDemoPage> {
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_seeded) {
      _seeded = true;
      ensureSeedData().then((_) => setState(() {}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final goals = context.watch<GoalProvider>().goals;
    return Scaffold(
      appBar: AppBar(title: const Text('My Journey · Demo')),
      body: goals.isEmpty
          ? const Center(child: Text('暂无数据，正在准备种子数据…'))
          : ListView.separated(
              itemCount: goals.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final g = goals[i];
                return _GoalTile(g: g);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final key = await context.read<GoalProvider>().addGoal(
                Goal(title: '新目标（示例）', description: '点击添加的占位目标', priority: 3),
              );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('已新增 Goal：$key')),
            );
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  final Goal g;
  const _GoalTile({required this.g});

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final tasks = taskProvider.tasksByGoal(g.key as int);
    return ExpansionTile(
      title: Text(g.title),
      subtitle: Text(g.description ?? ''),
      children: [
        if (g.kpis.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 12,
              children: g.kpis
                  .map((k) => Chip(
                        label: Text('${k.name} ${k.currentValue}/${k.targetValue}${k.unit} (${k.period})'),
                      ))
                  .toList(),
            ),
          ),
        ...tasks.map((t) => CheckboxListTile(
              title: Text(t.title),
              subtitle: t.note != null ? Text(t.note!) : null,
              value: t.done,
              onChanged: (_) => taskProvider.toggleDone(t.key as int),
            )),
        const SizedBox(height: 8),
      ],
    );
  }
}

