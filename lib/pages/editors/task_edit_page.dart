// lib/pages/editors/task_edit_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/task.dart';
import '../../providers/task_provider.dart';
import '../../core/result.dart'; // ✅ 用于判断 addTask 返回 Success/Failure
import '../../widgets/color_picker.dart';

/// 编辑模式参数（旧逻辑兼容）
class TaskEditArgs {
  final int taskKey;
  const TaskEditArgs({required this.taskKey});
}

class TaskEditPage extends StatefulWidget {
  const TaskEditPage({super.key});

  static const route = '/task/edit';

  @override
  State<TaskEditPage> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends State<TaskEditPage> {
  final _formKey = GlobalKey<FormState>();

  bool _inited = false;
  bool _saving = false;

  // mode
  bool _isCreate = false;

  // create args
  int? _createGoalId;
  int? _createSubGoalId;
  DateTime? _createDate;

  // edit args
  int? _taskKey;
  Task? _task; // Hive object (edit mode)

  late final TextEditingController _titleCtrl;
  late final TextEditingController _noteCtrl;

  // 🆕 topic（W6）
  late final TextEditingController _topicCtrl;

  // 🆕 W6
  late final TextEditingController _locationCtrl;
  late final TextEditingController _participantsCtrl;

  int _priority = 3;
  bool _isAllDay = false;

  DateTime? _startAt;
  DateTime? _endAt;
  DateTime? _deadline;

  double _completion = 0.0;
  bool _done = false;

  int? _color; // null = 继承/默认

  // 🆕 W6 alarm
  bool _hasAlarm = false;
  DateTime? _alarmAt;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _noteCtrl = TextEditingController();
    _topicCtrl = TextEditingController();
    _locationCtrl = TextEditingController();
    _participantsCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _topicCtrl.dispose();
    _locationCtrl.dispose();
    _participantsCtrl.dispose();
    super.dispose();
  }

  void _initIfNeeded(BuildContext context) {
    if (_inited) return;
    _inited = true;

    final args = ModalRoute.of(context)?.settings.arguments;

    // ====== 1) 编辑模式：TaskEditArgs(taskKey) ======
    if (args is TaskEditArgs) {
      _isCreate = false;
      _taskKey = args.taskKey;

      final provider = context.read<TaskProvider>();
      final t = provider.getByKey(args.taskKey);
      if (t == null) return;

      _task = t;

      _titleCtrl.text = t.title;
      _noteCtrl.text = t.note ?? '';
      _topicCtrl.text = t.topic ?? '';

      _priority = t.priority;
      _isAllDay = t.isAllDay;

      _startAt = t.startAt;
      _endAt = t.endAt;
      _deadline = t.deadline;

      _completion = t.completion.clamp(0.0, 1.0);
      _done = t.done;

      _color = t.color;

      // 🆕 W6
      _locationCtrl.text = t.location ?? '';
      _participantsCtrl.text = (t.participantEmailsRaw ?? '').trim();
      _hasAlarm = t.hasAlarm;
      _alarmAt = t.alarmAt;

      return;
    }

    // ====== 2) 新增模式：Map 参数（兼容 MyJourney 等页面的 pushNamed） ======
    if (args is Map) {
      _isCreate = true;

      final m = Map<String, dynamic>.from(args);
      _createGoalId = m['goalId'] as int?;
      _createSubGoalId = m['subGoalId'] as int?;
      final d = m['date'];
      _createDate = d is DateTime ? d : null;

      final base = _createDate ?? DateTime.now();
      _startAt = DateTime(base.year, base.month, base.day, 9, 0);
      _deadline = DateTime(base.year, base.month, base.day);

      // 给个默认标题占位，用户可改
      _titleCtrl.text = '新任务';
      _topicCtrl.text = '';
      _priority = 3;
      _isAllDay = false;
      _completion = 0.0;
      _done = false;
      _color = null;

      // 🆕 W6 默认值
      _locationCtrl.text = '';
      _participantsCtrl.text = '';
      _hasAlarm = false;
      _alarmAt = null;

      return;
    }

    // ====== 3) 无参数：也允许进入新增（防白屏） ======
    _isCreate = true;
    final base = DateTime.now();
    _startAt = DateTime(base.year, base.month, base.day, 9, 0);
    _deadline = DateTime(base.year, base.month, base.day);
    _titleCtrl.text = '新任务';
    _topicCtrl.text = '';

    // 🆕 W6 默认值
    _locationCtrl.text = '';
    _participantsCtrl.text = '';
    _hasAlarm = false;
    _alarmAt = null;
  }

  Future<DateTime?> _pickDateTime({
    required DateTime initial,
    required bool pickTime,
  }) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null) return null;
    if (!pickTime) return DateTime(date.year, date.month, date.day);

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return DateTime(date.year, date.month, date.day);

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _fmtDT(DateTime? d) {
    if (d == null) return '未设置';
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$day $hh:$mm';
  }

  /// 规范化参与者邮箱输入（MVP）：
  /// - 支持逗号、顿号、分号、空格、换行分隔
  /// - 去重、去空
  String _normalizeParticipantsRaw(String raw) {
    final s = raw
        .replaceAll('，', ',')
        .replaceAll(';', ',')
        .replaceAll('；', ',')
        .replaceAll('\n', ',')
        .replaceAll('\t', ',');
    final parts = s
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final seen = <String>{};
    final out = <String>[];
    for (final p in parts) {
      final lower = p.toLowerCase();
      if (seen.add(lower)) out.add(p);
    }
    return out.join(', ');
  }

  Future<void> _save() async {
    if (_saving) return;

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _saving = true);

    try {
      final provider = context.read<TaskProvider>();

      final participantsRaw = _normalizeParticipantsRaw(_participantsCtrl.text);
      final location = _locationCtrl.text.trim().isEmpty
          ? null
          : _locationCtrl.text.trim();

      final topic = _topicCtrl.text.trim().isEmpty ? null : _topicCtrl.text.trim();

      // ✅ alarm 逻辑（修复：默认值落在过去导致不调度）
      DateTime? alarmAt = _alarmAt;
      final now = DateTime.now();
      if (!_hasAlarm) {
        alarmAt = null;
      } else {
        alarmAt ??= (_startAt != null
            ? _startAt!.subtract(const Duration(minutes: 10))
            : now.add(const Duration(hours: 1)));

        // 过去时间不合法：兜底为 1 小时后
        if (alarmAt.isBefore(now)) {
          alarmAt = now.add(const Duration(hours: 1));
        }
      }

      // ====== 新增模式 ======
      if (_isCreate) {
        final title =
            _titleCtrl.text.trim().isEmpty ? '新任务' : _titleCtrl.text.trim();

        final newTask = Task(
          title: title,
          topic: topic,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          goalId: _createGoalId,
          subGoalId: _createSubGoalId,
          priority: _priority,
          isAllDay: _isAllDay,
          startAt: _startAt,
          endAt: _endAt,
          deadline: _deadline,
          completion: _done ? 1.0 : _completion.clamp(0.0, 1.0),
          done: _done,
          color: _color,

          // 🆕 W6
          location: location,
          participantEmailsRaw: participantsRaw.isEmpty ? null : participantsRaw,
          hasAlarm: _hasAlarm,
          alarmAt: alarmAt,
        );

        if (newTask.done) newTask.completion = 1.0;

        // ✅ addTask 返回 Result：失败不会 throw，所以这里要处理
        final result = await provider.addTask(newTask);
        if (result is Failure) {
          throw result.error;
        }

        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }

      // ====== 编辑模式 ======
      final t = _task;
      if (t == null) {
        throw Exception('Task not found');
      }

      // key 兜底：防止 updateTask 静默失败
      final key = t.key;
      if (key is! int) {
        throw Exception('Invalid task key');
      }

      t
        ..title =
            _titleCtrl.text.trim().isEmpty ? t.title : _titleCtrl.text.trim()
        ..topic = topic
        ..note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim()
        ..priority = _priority
        ..isAllDay = _isAllDay
        ..startAt = _startAt
        ..endAt = _endAt
        ..deadline = _deadline
        ..completion = _done ? 1.0 : _completion.clamp(0.0, 1.0)
        ..done = _done
        ..color = _color

        // 🆕 W6
        ..location = location
        ..participantEmailsRaw =
            participantsRaw.isEmpty ? null : participantsRaw
        ..hasAlarm = _hasAlarm
        ..alarmAt = alarmAt;

      if (t.done) t.completion = 1.0;

      await provider.updateTask(t);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_isCreate) return;

    final key = _taskKey;
    if (key == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除任务？'),
        content: const Text('删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final provider = context.read<TaskProvider>();
    await provider.deleteTask(key);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    _initIfNeeded(context);

    if (!_isCreate && _task == null) {
      return const Scaffold(
        body: Center(child: Text('任务不存在或参数错误')),
      );
    }

    final isGoalTask =
        _isCreate ? (_createGoalId != null) : (_task?.goalId != null);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isCreate ? '新增日程/任务' : '编辑日程/任务'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const Text('保存中...') : const Text('保存'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // 标题
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: '标题',
                  hintText: '例如：复习 FP2 / 和客户开会',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '请输入标题' : null,
              ),
              const SizedBox(height: 12),

              // Topic（可选）
              TextFormField(
                controller: _topicCtrl,
                decoration: const InputDecoration(
                  labelText: 'Topic（可选）',
                  hintText: '例如：Work / Study / Health',
                ),
              ),
              const SizedBox(height: 12),

              // 备注
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: '备忘录（可选）',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),

              // 地点
              TextFormField(
                controller: _locationCtrl,
                decoration: const InputDecoration(
                  labelText: '地点（可选）',
                  hintText: '例如：Ginza / Zoom / Office',
                ),
              ),
              const SizedBox(height: 12),

              // 参与者
              TextFormField(
                controller: _participantsCtrl,
                decoration: const InputDecoration(
                  labelText: '参与者邮箱（可选）',
                  hintText: '多个邮箱用逗号或换行分隔',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Text(
                'MVP：这里只做“已邀请”本地记录（不发送邮件）。后续可接真实邀请与状态同步。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),

              // Alarm
              Row(
                children: [
                  Switch(
                    value: _hasAlarm,
                    onChanged: (v) => setState(() {
                      _hasAlarm = v;
                      if (!v) _alarmAt = null;
                    }),
                  ),
                  const SizedBox(width: 8),
                  const Text('提醒（alarm）'),
                  const Spacer(),
                  Text(
                    _hasAlarm ? _fmtDT(_alarmAt) : '未开启',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
              if (_hasAlarm) ...[
                const SizedBox(height: 8),
                _TimeRow(
                  label: '提醒时间',
                  value: _fmtDT(_alarmAt),
                  onTap: () async {
                    final init = _alarmAt ?? _startAt ?? DateTime.now();
                    final dt = await _pickDateTime(
                      initial: init,
                      pickTime: true,
                    );
                    if (dt == null) return;
                    setState(() => _alarmAt = dt);
                  },
                  onClear: () => setState(() => _alarmAt = null),
                ),
              ],
              const SizedBox(height: 12),

              // 完成 / 完成度
              Row(
                children: [
                  Switch(
                    value: _done,
                    onChanged: (v) => setState(() {
                      _done = v;
                      if (v) _completion = 1.0;
                    }),
                  ),
                  const SizedBox(width: 8),
                  Text(_done ? '已完成' : '未完成'),
                  const Spacer(),
                  Text(
                    'P$_priority',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 完成度（done 时锁定）
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '完成度（0-100%）',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  Slider(
                    value: _done ? 1.0 : _completion,
                    onChanged:
                        _done ? null : (v) => setState(() => _completion = v),
                  ),
                  Text(
                    '${((_done ? 1.0 : _completion) * 100).round()}%',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 优先度
              Row(
                children: [
                  const Text('优先度'),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _priority,
                    items: const [1, 2, 3, 4, 5]
                        .map((v) =>
                            DropdownMenuItem(value: v, child: Text('P$v')))
                        .toList(),
                    onChanged: (v) => setState(() => _priority = v ?? 3),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 全日
              Row(
                children: [
                  Switch(
                    value: _isAllDay,
                    onChanged: (v) => setState(() => _isAllDay = v),
                  ),
                  const Text('全日'),
                ],
              ),
              const SizedBox(height: 12),

              // 时间
              _TimeRow(
                label: '开始',
                value: _fmtDT(_startAt),
                onTap: () async {
                  final init = _startAt ?? DateTime.now();
                  final dt = await _pickDateTime(
                    initial: init,
                    pickTime: !_isAllDay,
                  );
                  if (dt == null) return;
                  setState(() => _startAt = dt);
                },
                onClear: () => setState(() => _startAt = null),
              ),
              const SizedBox(height: 8),
              _TimeRow(
                label: '结束',
                value: _fmtDT(_endAt),
                onTap: () async {
                  final init = _endAt ?? _startAt ?? DateTime.now();
                  final dt = await _pickDateTime(
                    initial: init,
                    pickTime: !_isAllDay,
                  );
                  if (dt == null) return;
                  setState(() => _endAt = dt);
                },
                onClear: () => setState(() => _endAt = null),
              ),
              const SizedBox(height: 8),
              _TimeRow(
                label: 'Deadline',
                value: _fmtDT(_deadline),
                onTap: () async {
                  final init = _deadline ?? _startAt ?? DateTime.now();
                  final dt = await _pickDateTime(
                    initial: init,
                    pickTime: false,
                  );
                  if (dt == null) return;
                  setState(() => _deadline = dt);
                },
                onClear: () => setState(() => _deadline = null),
              ),

              const SizedBox(height: 24),

              // 颜色
              Row(
                children: [
                  const Text('颜色', style: TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _color = null),
                    child: Text(isGoalTask ? '继承目标色' : '使用默认色'),
                  ),
                ],
              ),
              ColorPicker(
                selected: _color,
                onChanged: (c) => setState(() => _color = c),
              ),
              const SizedBox(height: 8),
              Text(
                isGoalTask
                    ? '说明：这是“目标相关任务”。不选颜色时，日历点会显示目标色；选择颜色则覆盖目标色。'
                    : '说明：这是“普通日程”。不选颜色时，日历点使用默认色；选择颜色则使用所选色。',
                style: Theme.of(context).textTheme.bodySmall,
              ),

              const SizedBox(height: 24),

              if (!_isCreate)
                OutlinedButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除任务'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _TimeRow({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 72, child: Text(label)),
        Expanded(
          child: Text(value, style: const TextStyle(color: Colors.black54)),
        ),
        TextButton(onPressed: onTap, child: const Text('设置')),
        TextButton(onPressed: onClear, child: const Text('清空')),
      ],
    );
  }
}
