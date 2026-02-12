// lib/pages/daily_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../adapters/dailylog_adapter.dart';
import '../adapters/task_adapter.dart';
import '../adapters/goal_tree_adapter.dart';

import '../models/task.dart' show Task hide TaskAdapter;
import '../providers/task_provider.dart';

import '../services/holiday_service.dart';
import 'editors/task_edit_page.dart';

enum _DailyView { week, month }

class DailyPage extends StatefulWidget {
  const DailyPage({super.key});

  @override
  State<DailyPage> createState() => _DailyPageState();
}

class _DailyPageState extends State<DailyPage> {
  _DailyView _view = _DailyView.week;
  DateTime _selectedDate = DateTime.now();

  int? _timerTaskId;
  bool _timerRunning = false;

  final TextEditingController _quickLogController = TextEditingController();
  final TextEditingController _newTaskTitleController = TextEditingController();

  final Map<String, String> _holidayCache = {}; // key: YYYY-MM-DD
  bool _holidayLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refreshHolidayCacheForCurrentView();
      if (mounted) setState(() => _holidayLoaded = true);
    });
  }

  @override
  void dispose() {
    _quickLogController.dispose();
    _newTaskTitleController.dispose();
    super.dispose();
  }

  // ---------------- Holiday ----------------

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isHoliday(DateTime day) => _holidayCache.containsKey(_dateKey(day));
  String? _holidayName(DateTime day) => _holidayCache[_dateKey(day)];

  Future<void> _prefetchYearsAround(DateTime day) async {
    final years = {day.year - 1, day.year, day.year + 1};
    await HolidayService.I.prefetchYears(years);
  }

  List<DateTime> _visibleDaysForWeekStrip(DateTime selected) {
    final s = _dateOnly(selected);
    final weekday = s.weekday; // Mon=1..Sun=7
    final startOfWeek = s.subtract(Duration(days: weekday - 1));
    return List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
  }

  Future<void> _refreshHolidayCacheForCurrentView() async {
    final selected = _dateOnly(_selectedDate);

    await _prefetchYearsAround(selected);

    if (_view == _DailyView.week) {
      final days = _visibleDaysForWeekStrip(selected);
      for (final d in days) {
        final name = await HolidayService.I.nameOf(d);
        final k = _dateKey(d);
        if (name != null && name.trim().isNotEmpty) {
          _holidayCache[k] = name;
        } else {
          _holidayCache.remove(k);
        }
      }
      return;
    }

    final name = await HolidayService.I.nameOf(selected);
    final k = _dateKey(selected);
    if (name != null && name.trim().isNotEmpty) {
      _holidayCache[k] = name;
    } else {
      _holidayCache.remove(k);
    }
  }

  Future<void> _setSelectedDate(DateTime d) async {
    setState(() => _selectedDate = d);
    await _refreshHolidayCacheForCurrentView();
    if (mounted) setState(() {});
  }

  Future<void> _setView(_DailyView v) async {
    setState(() => _view = v);
    await _refreshHolidayCacheForCurrentView();
    if (mounted) setState(() {});
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final daily = context.watch<DailyLogAdapter>();
    final taskAdapter = context.watch<TaskAdapter>();

    final tasks = taskAdapter.tasksForDate(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily'),
        actions: [
          if (!_holidayLoaded)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  '祝日加载中…',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ),
        ],
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
                const SizedBox(height: 12),
                _buildCalendar(),
                const SizedBox(height: 16),
                _buildKpiCard(daily),
                const SizedBox(height: 16),
                _buildTop3Card(taskAdapter),
                const SizedBox(height: 16),
                _buildTaskList(taskAdapter, tasks),
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
          onPressed: () => _setView(_DailyView.week),
          child: const Text('周视图'),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          key: const Key('daily.view.month'),
          onPressed: () => _setView(_DailyView.month),
          child: const Text('月视图'),
        ),
      ],
    );
  }

  // ---------------- Calendar (Week / Month) ----------------

  Widget _buildCalendar() {
    final selected = _dateOnly(_selectedDate);
    final holiday = _holidayName(selected);

    return Card(
      key: const Key('daily.calendar.card'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                if (holiday != null)
                  Text(
                    holiday,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: '今天',
                  onPressed: () => _setSelectedDate(DateTime.now()),
                  icon: const Icon(Icons.today),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_view == _DailyView.month) _buildMonthPicker() else _buildWeekStrip(),
            const SizedBox(height: 8),
            const Text(
              '● 表示当天有任务；点颜色=任务色（优先）或目标色；红字为祝日',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthPicker() {
    return CalendarDatePicker(
      initialDate: _dateOnly(_selectedDate),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      onDateChanged: (d) => _setSelectedDate(d),
    );
  }

  Widget _buildWeekStrip() {
    final selected = _dateOnly(_selectedDate);
    final days = _visibleDaysForWeekStrip(selected);

    // ✅ 测试环境可能没有提供 GoalTreeAdapter / TaskProvider：降级为空，不要抛 ProviderNotFound
    final GoalTreeAdapter? goalTree = Provider.of<GoalTreeAdapter?>(context);
    final TaskProvider? taskProvider = Provider.of<TaskProvider?>(context);

    final Map<int, Color> goalColorById = {
      for (final g in (goalTree?.goals ?? const [])) g.goalKey: g.color,
    };

    List<Color> _dayDotColors(DateTime day) {
      final List<Task> list = taskProvider?.tasksForDate(day) ?? const <Task>[];
      if (list.isEmpty) return const [];

      final sorted = [...list]..sort(GoalTreeAdapter.taskSort);

      final colors = <Color>[];
      for (final t in sorted) {
        final Color c = (t.color != null)
            ? Color(t.color!)
            : (t.goalId != null && goalColorById[t.goalId!] != null)
                ? goalColorById[t.goalId!]!
                : Theme.of(context).colorScheme.primary;

        if (!colors.any((x) => x.value == c.value)) {
          colors.add(c);
        }
        if (colors.length >= 3) break;
      }
      return colors;
    }

    return Row(
      children: [
        IconButton(
          tooltip: '上一周',
          onPressed: () => _setSelectedDate(selected.subtract(const Duration(days: 7))),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Row(
            children: days.map((d) {
              final isSelected = _isSameDay(d, selected);
              final isHoliday = _isHoliday(d);

              final dotColors = _dayDotColors(d);

              return Expanded(
                child: InkWell(
                  onTap: () => _setSelectedDate(d),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _weekdayLabel(d.weekday),
                          style: const TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).dividerColor.withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            '${d.day}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isHoliday ? Colors.red : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 10,
                          child: dotColors.isEmpty
                              ? const SizedBox.shrink()
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: dotColors
                                      .map(
                                        (c) => Container(
                                          width: 6,
                                          height: 6,
                                          margin: const EdgeInsets.symmetric(horizontal: 2),
                                          decoration: BoxDecoration(
                                            color: c,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        IconButton(
          tooltip: '下一周',
          onPressed: () => _setSelectedDate(selected.add(const Duration(days: 7))),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return '一';
      case DateTime.tuesday:
        return '二';
      case DateTime.wednesday:
        return '三';
      case DateTime.thursday:
        return '四';
      case DateTime.friday:
        return '五';
      case DateTime.saturday:
        return '六';
      case DateTime.sunday:
        return '日';
      default:
        return '';
    }
  }

  // ---------------- KPI 卡片 ----------------

  Widget _buildKpiCard(DailyLogAdapter daily) {
    final weekly = daily.weeklyStats(now: _selectedDate);
    final hours = weekly.totalHours;
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
            Text(tip, key: const Key('daily.kpi.tip')),
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

  // ---------------- 任务列表 ----------------

  Widget _buildTaskList(TaskAdapter taskAdapter, List<TaskVM> tasks) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('今日任务'),
        const SizedBox(height: 8),
        for (final t in tasks)
          ListTile(
            key: Key('daily.task.item.${t.id}'),
            title: Text(t.title),
            subtitle: _buildTaskSubtitle(t),
            onTap: () async {
              await Navigator.of(context).pushNamed(
                TaskEditPage.route,
                arguments: TaskEditArgs(taskKey: t.id),
              );
            },
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: t.done ? '标记未完成' : '标记完成',
                  icon: Icon(t.done ? Icons.check_circle : Icons.circle_outlined),
                  onPressed: () async {
                    await taskAdapter.toggleTaskDone(t.id, !t.done);
                  },
                ),
                IconButton(
                  key: Key('daily.task.timer.${t.id}'),
                  icon: Icon(
                    _timerRunning && _timerTaskId == t.id
                        ? Icons.pause_circle_filled
                        : Icons.play_circle,
                  ),
                  onPressed: () => _onTimerPressed(t),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget? _buildTaskSubtitle(TaskVM t) {
    final parts = <String>[];
    try {
      if ((t as dynamic).isAllDay == true) {
        parts.add('全日');
      } else {
        final s = (t as dynamic).startAt as DateTime?;
        final e = (t as dynamic).endAt as DateTime?;
        if (s != null) {
          final ss = '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}';
          if (e != null) {
            final ee = '${e.hour.toString().padLeft(2, '0')}:${e.minute.toString().padLeft(2, '0')}';
            parts.add('$ss-$ee');
          } else {
            parts.add(ss);
          }
        }
      }

      final loc = (t as dynamic).location as String?;
      if (loc != null && loc.trim().isNotEmpty) parts.add(loc.trim());

      final pe = (t as dynamic).participantEmails as List?;
      if (pe != null && pe.isNotEmpty) parts.add('${pe.length}人');

      final pri = (t as dynamic).priority as int?;
      if (pri != null) parts.add('P$pri');

      final comp = (t as dynamic).completion as double?;
      if (comp != null) parts.add('${(comp * 100).round()}%');
    } catch (_) {}

    if (parts.isEmpty) return null;
    return Text(parts.join(' · '));
  }

  void _onTimerPressed(TaskVM task) {
    if (!_timerRunning || _timerTaskId != task.id) {
      setState(() {
        _timerRunning = true;
        _timerTaskId = task.id;
      });
      return;
    }

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
                if (mounted) Navigator.of(ctx).pop();
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
              decoration: const InputDecoration(hintText: '写点今天的投入 / 反思...'),
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
            decoration: const InputDecoration(labelText: '任务标题'),
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
                await taskAdapter.newTask(title: title, date: _selectedDate);

                _newTaskTitleController.clear();
                if (mounted) Navigator.of(ctx).pop();
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }
}

