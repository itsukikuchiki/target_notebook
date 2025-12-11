// lib/pages/daily_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../adapters/dailylog_adapter.dart';
import '../adapters/task_adapter.dart';

enum _DailyView { week, month }

class DailyPage extends StatefulWidget {
  const DailyPage({super.key});

  @override
  State<DailyPage> createState() => _DailyPageState();
}

class _DailyPageState extends State<DailyPage> {
  _DailyView _view = _DailyView.week;
  DateTime _selectedDate = DateTime.now();

  // 计时器状态
  int? _timerTaskId;
  bool _timerRunning = false;

  // 快速日志
  final TextEditingController _quickLogController = TextEditingController();

  // 新任务
  final TextEditingController _newTaskTitleController = TextEditingController();

  @override
  void dispose() {
    _quickLogController.dispose();
    _newTaskTitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final daily = context.watch<DailyLogAdapter>();
    final taskAdapter = context.watch<TaskAdapter>();

    final tasks = taskAdapter.tasksForDate(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily'),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('daily.addTask.fab'),
        onPressed: _openNewTaskDialog,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              key: const Key('daily.root.column'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildViewToggle(),
                const SizedBox(height: 16),
                _buildKpiCard(daily),
                const SizedBox(height: 16),
                _buildTop3Card(taskAdapter),
                const SizedBox(height: 16),
                _buildTaskList(tasks),
                const SizedBox(height: 16),
                _buildQuickLogArea(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- 视图切换 ----------------

  Widget _buildViewToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton(
          key: const Key('daily.view.week'),
          onPressed: () {
            setState(() => _view = _DailyView.week);
          },
          child: const Text('周视图'),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          key: const Key('daily.view.month'),
          onPressed: () {
            setState(() => _view = _DailyView.month);
          },
          child: const Text('月视图'),
        ),
      ],
    );
  }

  // ---------------- KPI 卡片 ----------------

  Widget _buildKpiCard(DailyLogAdapter daily) {
    final weekly = daily.weeklyStats(now: _selectedDate);
    final hours = weekly.totalHours; // WeeklyStatsVM 中添加的 getter
    final tip = weekly.tip;

    return Card(
      key: const Key('daily.kpi.card'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('本周投入'),
            const SizedBox(height: 8),
            Text(
              '${hours.toStringAsFixed(1)} h',
              key: const Key('daily.kpi.hours'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              tip,
              key: const Key('daily.kpi.tip'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- 今日三件事 ----------------

  Widget _buildTop3Card(TaskAdapter taskAdapter) {
    final top3 = taskAdapter.top3ForDate(_selectedDate);

    return Card(
      key: const Key('daily.top3.card'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('今日三件事'),
            const SizedBox(height: 8),
            for (var i = 0; i < top3.length; i++)
              ListTile(
                key: Key('daily.top3.item.${i + 1}'),
                title: Text(top3[i].title),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------- 任务列表 + 计时器 ----------------

  Widget _buildTaskList(List<TaskVM> tasks) {
    if (tasks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('今日任务'),
        const SizedBox(height: 8),
        for (final t in tasks)
          ListTile(
            key: Key('daily.task.item.${t.id}'),
            title: Text(t.title),
            trailing: IconButton(
              key: Key('daily.task.timer.${t.id}'),
              icon: Icon(
                _timerRunning && _timerTaskId == t.id
                    ? Icons.pause_circle_filled
                    : Icons.play_circle,
              ),
              onPressed: () => _onTimerPressed(t),
            ),
          ),
      ],
    );
  }

  void _onTimerPressed(TaskVM task) {
    // 第一次点击：开始计时
    if (!_timerRunning || _timerTaskId != task.id) {
      setState(() {
        _timerRunning = true;
        _timerTaskId = task.id;
      });
      return;
    }

    // 第二次点击：结束计时并弹出保存对话框
    setState(() {
      _timerRunning = false;
      _timerTaskId = null;
    });

    _openTimerSaveDialog(task);
  }

  void _openTimerSaveDialog(TaskVM task) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('保存计时记录'),
          content: const Text('本次计时将记录为 25 分钟的投入。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              key: const Key('daily.timer.save'),
              onPressed: () async {
                final daily = ctx.read<DailyLogAdapter>();
                await daily.addQuickLog(
                  date: _selectedDate,
                  content: '计时-${task.title}',
                  minutes: 25,
                  taskId: task.id,
                );
                if (mounted) {
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  // ---------------- 快速日志区域 ----------------

  Widget _buildQuickLogArea() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('快速记录'),
            const SizedBox(height: 8),
            TextField(
              key: const Key('daily.quicklog.text'),
              controller: _quickLogController,
              decoration: const InputDecoration(
                hintText: '写点今天的投入 / 反思...',
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                key: const Key('daily.quicklog.save'),
                icon: const Icon(Icons.save),
                label: const Text('保存'),
                onPressed: () async {
                  final text = _quickLogController.text.trim();
                  if (text.isEmpty) return;

                  final daily = context.read<DailyLogAdapter>();
                  await daily.addQuickLog(
                    date: _selectedDate,
                    content: text,
                    minutes: 15,
                  );
                  _quickLogController.clear();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- 新建任务 Dialog ----------------

  void _openNewTaskDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          key: const Key('daily.addTask.dialog'),
          title: const Text('新增任务'),
          content: TextField(
            key: const Key('daily.addTask.title'),
            controller: _newTaskTitleController,
            decoration: const InputDecoration(
              labelText: '任务标题',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _newTaskTitleController.clear();
                Navigator.of(ctx).pop();
              },
              child: const Text('取消'),
            ),
            ElevatedButton(
              key: const Key('daily.addTask.save'),
              onPressed: () async {
                final title = _newTaskTitleController.text.trim();
                if (title.isEmpty) return;

                final taskAdapter = ctx.read<TaskAdapter>();
                await taskAdapter.newTask(
                  title: title,
                  date: _selectedDate,
                );
                _newTaskTitleController.clear();

                if (mounted) {
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }
}

