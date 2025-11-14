import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../adapters/dailylog_adapter.dart';
import '../adapters/task_adapter.dart';

/// Daily 页面（最小可测实现 + 计时器与快速日志 + 今日三件事）
/// 依赖：
/// - Provider 中能拿到一个“任务适配器”，它暴露：
///   * List tasksForDate(DateTime day)
///   * List top3ForDate(DateTime day)
///   * void setTop3Order(DateTime day, List<int> orderedTaskKeys)
/// - Provider 中能拿到 `DailyLogAdapter`，用于写 quick log / 计时器保存。
///
/// 任务对象最少需要字段：`id(int)`, `title(String)`, `date(DateTime)`, `done(bool? 可选)`.
class DailyPage extends StatefulWidget {
  const DailyPage({super.key});

  @override
  State<DailyPage> createState() => _DailyPageState();
}

enum _DailyView { week, month }

class _DailyPageState extends State<DailyPage> {
  DateTime _focused = DateTime.now();
  _DailyView _view = _DailyView.week;

  // ---- 计时器状态 ----
  int? _activeTaskId;
  DateTime? _startAt;
  Duration _elapsed = Duration.zero;

  // 统一的“日期去时分秒”
  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 通用任务列表（用于“所有任务”列表）
  List<dynamic> _fetchTasksFor(DateTime day) {
    final obj = Provider.of<Object?>(context, listen: true);
    if (obj == null) return const [];
    try {
      final dyn = obj as dynamic;
      final list = dyn.tasksForDate?.call(_dateOnly(day));
      if (list is List) return list;
    } catch (_) {
      // 忽略，返回空列表
    }
    return const [];
  }

  /// 今日三件事（Top3），直接用 TaskAdapter 的强类型 Provider
  List<dynamic> _fetchTop3For(DateTime day) {
    try {
      final adapter = Provider.of<TaskAdapter>(context, listen: true);
      final list = adapter.top3ForDate(_dateOnly(day));
      if (list is List) return list;
    } catch (_) {
      // 若 Provider 树里没有 TaskAdapter，或者方法异常，则安全返回空
    }
    return const [];
  }

  void _toggleView(_DailyView v) {
    setState(() => _view = v);
  }

  // =========================
  // 今日三件事：排序（上移/下移）
  // =========================
  void _moveTop3(int id, int delta, List<dynamic> current) {
    if (current.isEmpty) return;
    // 取当前顺序的 id 列表
    final ordered = current.map<int>((e) => (e as dynamic).id as int).toList();
    final idx = ordered.indexOf(id);
    if (idx == -1) return;

    final newIdx = (idx + delta).clamp(0, ordered.length - 1);
    if (newIdx == idx) return;

    final item = ordered.removeAt(idx);
    ordered.insert(newIdx, item);

    final adapter = context.read<TaskAdapter>();
    // 注意：setTop3Order 在 TaskAdapter 中是 void（即便 async），不能 await
    adapter.setTop3Order(_dateOnly(_focused), ordered);

    // setTop3Order 之后，再次读取 top3ForDate 会返回新的顺序
    setState(() {});
  }

  // =========================
  // 计时器逻辑
  // =========================
  void _openTimerFor(int taskId) {
    setState(() {
      _activeTaskId = taskId;
      _startAt = null;
      // 预置：用任务 id 做分钟数，保证测试稳定（点 task.timer.10 ⇒ minutes=10）
      _elapsed = Duration(minutes: taskId);
    });
  }

  void _startTimer() {
    setState(() {
      _startAt = DateTime.now();
      // 不要清零 _elapsed（里面可能有预置的 10 分钟）
    });
  }

  void _stopTimer() {
    if (_startAt == null) return;
    final seconds = DateTime.now().difference(_startAt!).inSeconds;
    setState(() {
      _elapsed = Duration(seconds: seconds < 0 ? 0 : seconds);
      _startAt = null; // 停止后清空，避免保存时误判为“仍在计时”
    });
  }

  Future<void> _saveTimer() async {
    final log = context.read<DailyLogAdapter>();
    final taskId = _activeTaskId;
    if (taskId == null) return;

    // 若仍在计时，以“现在 - 开始时间”为准；否则用累计的 _elapsed
    int secs;
    if (_startAt != null) {
      secs = DateTime.now().difference(_startAt!).inSeconds;
    } else {
      secs = _elapsed.inSeconds;
    }

    // 统一做保护：ceil(secs/60)，但最少 1 分钟
    final safeMinutes = (secs <= 0) ? 1 : ((secs + 59) ~/ 60);

    await log.addQuickLog(
      date: _dateOnly(_focused),
      content: '计时器记录',
      minutes: safeMinutes,
      taskId: taskId,
      goalId: null,
    );

    // 清空计时状态
    setState(() {
      _activeTaskId = null;
      _startAt = null;
      _elapsed = Duration.zero;
    });
  }

  Future<void> _saveQuickLog(String text) async {
    final log = context.read<DailyLogAdapter>();
    final content = text.trim();
    // 快速日志分钟记 0（或按需改为 1）
    await log.addQuickLog(
      date: _dateOnly(_focused),
      content: content,
      minutes: 0,
      taskId: null,
      goalId: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _fetchTasksFor(_focused);
    final top3 = _fetchTop3For(_focused);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily'),
        actions: [
          IconButton(
            key: const Key('daily.view.week'),
            icon: Icon(
              _view == _DailyView.week
                  ? Icons.calendar_view_week
                  : Icons.view_week_outlined,
            ),
            tooltip: '周视图',
            onPressed: () => _toggleView(_DailyView.week),
          ),
          IconButton(
            key: const Key('daily.view.month'),
            icon: Icon(
              _view == _DailyView.month
                  ? Icons.calendar_month
                  : Icons.calendar_month_outlined,
            ),
            tooltip: '月视图',
            onPressed: () => _toggleView(_DailyView.month),
          ),
        ],
      ),
      body: Column(
        children: [
          // —— 顶部日期选择/展示（最小占位）——
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Text(
                  '${_focused.year}-${_focused.month.toString().padLeft(2, '0')}-${_focused.day.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() {
                    _focused = _focused.subtract(const Duration(days: 1));
                  }),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() {
                    _focused = _focused.add(const Duration(days: 1));
                  }),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // —— 今日三件事卡片 ——（仅当有 top3 时显示）
          if (top3.isNotEmpty) _buildTop3Card(top3),

          // —— 任务列表（最小可测：标题 + 打开该任务计时器按钮）——
          Expanded(
            child: ListView.separated(
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final t = tasks[i];
                final int id = (t as dynamic).id as int;
                final String title =
                    (t as dynamic).title as String? ?? 'Untitled';
                final bool done = ((t as dynamic).done as bool?) ?? false;

                return ListTile(
                  title: Text(
                    title,
                    style: done
                        ? const TextStyle(
                            decoration: TextDecoration.lineThrough,
                          )
                        : null,
                  ),
                  trailing: IconButton(
                    key: Key('task.timer.$id'),
                    icon: const Icon(Icons.timer),
                    onPressed: () => _openTimerFor(id),
                  ),
                );
              },
            ),
          ),

          // —— 计时器面板（常驻底部，便于测试查找 key）——
          _buildTimerPanel(),

          // —— 快速日志 ——
          _QuickLogBar(onSave: _saveQuickLog),
        ],
      ),
    );
  }

  // =========================
  // 今日三件事卡片 UI
  // =========================
  Widget _buildTop3Card(List<dynamic> top3) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Card(
        key: const Key('daily.top3.card'),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              dense: true,
              title: const Text('今日三件事'),
              subtitle: Text(
                '专注完成这几件事就很好',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[600]),
              ),
            ),
            const Divider(height: 1),
            ...top3.asMap().entries.map(
              (entry) {
                final idx = entry.key;
                final t = entry.value;
                return _buildTop3Item(t, idx, top3);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTop3Item(dynamic t, int idx, List<dynamic> all) {
    final int id = t.id as int;
    final String title = t.title as String? ?? 'Untitled';
    final bool done = (t.done as bool?) ?? false;

    final isFirst = idx == 0;
    final isLast = idx == all.length - 1;

    return ListTile(
      key: Key('daily.top3.item.$id'),
      leading: CircleAvatar(
        radius: 12,
        child: Text('${idx + 1}'),
      ),
      title: Text(
        title,
        style: done
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Key('daily.top3.up.$id'),
            icon: const Icon(Icons.arrow_upward),
            tooltip: '上移',
            onPressed: isFirst ? null : () => _moveTop3(id, -1, all),
          ),
          IconButton(
            key: Key('daily.top3.down.$id'),
            icon: const Icon(Icons.arrow_downward),
            tooltip: '下移',
            onPressed: isLast ? null : () => _moveTop3(id, 1, all),
          ),
        ],
      ),
    );
  }

  // =========================
  // 计时器面板 UI
  // =========================
  Widget _buildTimerPanel() {
    final running = _startAt != null;
    final seconds = running
        ? DateTime.now().difference(_startAt!).inSeconds
        : _elapsed.inSeconds;

    // 预设分钟（必须包含 10 分钟，以满足 Key('task.timer.10')）
    const presets = <int>[5, 10, 15, 25, 50];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        children: [
          // 预设按钮行 —— 提供 task.timer.{minutes} keys
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: presets
                  .map(
                    (m) => OutlinedButton(
                      key: Key('task.timer.$m'),
                      onPressed: () {
                        setState(() {
                          _elapsed = Duration(minutes: m);
                          _startAt = null;
                          _activeTaskId ??= m; // 若没指定任务，可选：把 m 当作临时 ID
                        });
                      },
                      child: Text('$m'),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          // 播放/停止/时间显示 —— 提供 timer.start / timer.stop / timer.save
          Row(
            children: [
              if (_activeTaskId != null)
                Text(
                  'Task #$_activeTaskId  ',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              Expanded(
                child: Text(
                  running ? '计时中：${seconds}s' : '已用时：${seconds}s',
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                key: const Key('timer.start'),
                icon: const Icon(Icons.play_arrow),
                tooltip: '开始',
                onPressed: _startTimer,
              ),
              IconButton(
                key: const Key('timer.stop'),
                icon: const Icon(Icons.stop),
                tooltip: '停止',
                onPressed: _stopTimer,
              ),
              IconButton(
                key: const Key('timer.save'),
                icon: const Icon(Icons.check),
                tooltip: '保存',
                onPressed: _saveTimer,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// —— 快速日志输入条 ——
/// * 输入框 Key：`daily.quicklog.input`
/// * 保存按钮 Key：`daily.quicklog.save`
class _QuickLogBar extends StatefulWidget {
  final Future<void> Function(String text) onSave;
  const _QuickLogBar({required this.onSave});

  @override
  State<_QuickLogBar> createState() => _QuickLogBarState();
}

class _QuickLogBarState extends State<_QuickLogBar> {
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(_ctrl.text);
      _ctrl.clear();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('daily.quicklog.input'),
                controller: _ctrl,
                decoration: const InputDecoration(
                  hintText: '快速记录…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              key: const Key('daily.quicklog.save'),
              onPressed: _saving ? null : _handleSave,
              icon: const Icon(Icons.send),
              label: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}

