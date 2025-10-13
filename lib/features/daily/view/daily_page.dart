import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/task_provider.dart';
import '../../../models/task.dart';

class DailyPage extends StatefulWidget {
  const DailyPage({super.key});
  @override
  State<DailyPage> createState() => _DailyPageState();
}

class _DailyPageState extends State<DailyPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addQuick(BuildContext context) async {
    final text = _controller.text;
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入任务标题')),
      );
      return;
    }
    await context.read<TaskProvider>().addQuickTaskToday(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now(); // 设备本地时间；JST 下系统即为 JST
    final tasks = context.watch<TaskProvider>().tasksForDay(today);

    return Scaffold(
      appBar: AppBar(
        title: Text('Daily · ${_fmtDate(today)}'),
      ),
      body: Column(
        children: [
          // 快速新增
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '输入今日任务…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addQuick(context),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _addQuick(context),
                  icon: const Icon(Icons.add_task),
                  label: const Text('添加'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 列表
          Expanded(
            child: tasks.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) => _TaskTile(task: tasks[i]),
                  ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final w = ['月','火','水','木','金','土','日'][(d.weekday % 7)];
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}（$w）';
  }
}

class _TaskTile extends StatelessWidget {
  final Task task;
  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      title: Text(
        task.title,
        style: task.done ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
      ),
      subtitle: task.note != null ? Text(task.note!) : null,
      value: task.done,
      onChanged: (_) => context.read<TaskProvider>().toggleDone(task.key as int),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Text('今天还没有任务。试试上方的输入框，快速添加一个吧！'),
      ),
    );
  }
}

