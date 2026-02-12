import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/task.dart';
import '../../providers/task_provider.dart';
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

  int _priority = 3;
  bool _isAllDay = false;

  DateTime? _startAt;
  DateTime? _endAt;
  DateTime? _deadline;

  double _completion = 0.0;
  bool _done = false;

  int? _color; // null = 继承/默认

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _noteCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
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

      _priority = t.priority;
      _isAllDay = t.isAllDay;

      _startAt = t.startAt;
      _endAt = t.endAt;
      _deadline = t.deadline;

      _completion = t.completion.clamp(0.0, 1.0);
      _done = t.done;

      _color = t.color;

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
      _priority = 3;
      _isAllDay = false;
      _completion = 0.0;
      _done = false;
      _color = null;

      return;
    }

    // ====== 3) 无参数：也允许进入新增（防白屏） ======
    _isCreate = true;
    final base = DateTime.now();
    _startAt = DateTime(base.year, base.month, base.day, 9, 0);
    _deadline = DateTime(base.year, base.month, base.day);
    _titleCtrl.text = '新任务';
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

  Future<void> _save() async {
    if (_saving) return;

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _saving = true);

    try {
      final provider = context.read<TaskProvider>();

      // ====== 新增模式 ======
      if (_isCreate) {
        final title = _titleCtrl.text.trim().isEmpty ? '新任务' : _titleCtrl.text.trim();

        final newTask = Task(
          title: title,
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
        );

        // done=true 时保持一致性
        if (newTask.done) newTask.completion = 1.0;

        // ✅ addTask 返回 Result<int>（或类似），这里不做错误类型猜测，交给 provider/异常机制
        await provider.addTask(newTask);

        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }

      // ====== 编辑模式 ======
      final t = _task;
      if (t == null) {
        throw Exception('Task not found');
      }

      t
        ..title = _titleCtrl.text.trim().isEmpty ? t.title : _titleCtrl.text.trim()
        ..note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim()
        ..priority = _priority
        ..isAllDay = _isAllDay
        ..startAt = _startAt
        ..endAt = _endAt
        ..deadline = _deadline
        ..completion = _done ? 1.0 : _completion.clamp(0.0, 1.0)
        ..done = _done
        ..color = _color;

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
    // 新增模式没有可删对象
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

    // 旧逻辑：如果是编辑模式但取不到 task，就显示错误
    if (!_isCreate && _task == null) {
      return const Scaffold(
        body: Center(child: Text('任务不存在或参数错误')),
      );
    }

    final isGoalTask = _isCreate ? (_createGoalId != null) : (_task?.goalId != null);

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
                validator: (v) => (v == null || v.trim().isEmpty) ? '请输入标题' : null,
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
                  Text('P$_priority', style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),

              // 完成度（done 时锁定）
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('完成度（0-100%）', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  Slider(
                    value: _done ? 1.0 : _completion,
                    onChanged: _done ? null : (v) => setState(() => _completion = v),
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
                        .map((v) => DropdownMenuItem(value: v, child: Text('P$v')))
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

