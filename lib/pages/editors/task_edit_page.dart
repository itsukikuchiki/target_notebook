import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/task.dart';
import '../../providers/task_provider.dart';

class TaskEditPage extends StatefulWidget {
  const TaskEditPage({super.key});
  static const route = '/task/edit';

  @override
  State<TaskEditPage> createState() => _TaskEditPageState();
}

/// 路由参数：
/// - goalId / subGoalId：新增时用于挂载到目标树
/// - taskKey：编辑模式（优先）
class TaskEditArgs {
  final int? goalId;
  final int? subGoalId;
  final int? taskKey;

  const TaskEditArgs({
    this.goalId,
    this.subGoalId,
    this.taskKey,
  });

  /// 兼容 Map 传参
  static TaskEditArgs? tryParse(Object? args) {
    if (args is TaskEditArgs) return args;
    if (args is Map) {
      return TaskEditArgs(
        goalId: args['goalId'] as int?,
        subGoalId: args['subGoalId'] as int?,
        taskKey: args['taskKey'] as int?,
      );
    }
    return null;
  }
}

class _TaskEditPageState extends State<TaskEditPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _participantsCtrl;

  int _priority = 3;
  bool _isAllDay = false;

  DateTime _startAt = DateTime.now();
  DateTime? _endAt;

  bool _hasAlarm = false;
  DateTime? _alarmAt;

  double _completion = 0.0;
  DateTime? _deadline;

  int? _color; // ✅ 新增：Task 颜色

  bool _inited = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _noteCtrl = TextEditingController();
    _locationCtrl = TextEditingController();
    _participantsCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _locationCtrl.dispose();
    _participantsCtrl.dispose();
    super.dispose();
  }

  void _initFromArgs(TaskEditArgs args) {
    if (_inited) return;
    _inited = true;

    final now = DateTime.now();
    _startAt = DateTime(now.year, now.month, now.day, now.hour, now.minute);

    if (args.taskKey == null) return;

    final provider = context.read<TaskProvider>();
    final t = provider.getByKey(args.taskKey!);
    if (t == null) return;

    _titleCtrl.text = t.title;
    _noteCtrl.text = t.note ?? '';
    _locationCtrl.text = t.location ?? '';
    _participantsCtrl.text = t.participantEmailsRaw ?? '';

    _priority = t.priority;
    _isAllDay = t.isAllDay;
    _startAt = t.startAt ?? _startAt;
    _endAt = t.endAt;

    _hasAlarm = t.hasAlarm;
    _alarmAt = t.alarmAt;

    _completion = t.effectiveCompletion;
    _deadline = t.deadline;
    _color = t.color; // ✅
  }

  Future<void> _pickDateTime({
    required DateTime initial,
    required ValueChanged<DateTime> onPicked,
    bool pickTime = true,
  }) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null) return;

    if (!pickTime) {
      onPicked(DateTime(date.year, date.month, date.day));
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;

    onPicked(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _save(TaskEditArgs args) async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    try {
      final provider = context.read<TaskProvider>();

      DateTime startAt = _startAt;
      DateTime? endAt = _endAt;

      if (_isAllDay) {
        startAt = DateTime(startAt.year, startAt.month, startAt.day);
        endAt = endAt != null
            ? DateTime(endAt.year, endAt.month, endAt.day, 23, 59)
            : null;
      } else if (endAt != null && endAt.isBefore(startAt)) {
        endAt = null;
      }

      final patch = Task(
        title: _titleCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        goalId: args.goalId,
        subGoalId: args.subGoalId,
        priority: _priority,
        isAllDay: _isAllDay,
        startAt: startAt,
        endAt: endAt,
        hasAlarm: _hasAlarm,
        alarmAt: _hasAlarm ? _alarmAt : null,
        location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
        participantEmailsRaw:
            _participantsCtrl.text.trim().isEmpty ? null : _participantsCtrl.text.trim(),
        completion: _completion.clamp(0.0, 1.0),
        deadline: _deadline,
        color: _color, // ✅
      );

      if (args.taskKey == null) {
        await provider.addTask(patch);
      } else {
        await provider.updateTask(args.taskKey!, patch);
      }

      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args =
        TaskEditArgs.tryParse(ModalRoute.of(context)?.settings.arguments) ??
            const TaskEditArgs();

    _initFromArgs(args);

    return Scaffold(
      appBar: AppBar(
        title: Text(args.taskKey != null ? '编辑任务' : '新增任务'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _save(args),
            child: const Text('保存'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: '标题'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '请输入标题' : null,
              ),
              const SizedBox(height: 16),

              _ColorRow(
                color: _color,
                onChanged: (c) => setState(() => _color = c),
              ),

              const SizedBox(height: 24),
              Text(
                '说明：\n'
                '- 不选颜色时，任务将继承子目标 / 目标颜色\n'
                '- 颜色用于日历、目标树、统计区分',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ======================
/// Color Picker（与 SubGoal 同风格）
/// ======================
class _ColorRow extends StatelessWidget {
  final int? color;
  final ValueChanged<int?> onChanged;

  const _ColorRow({required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const palette = <int>[
      0xFFEF5350,
      0xFFAB47BC,
      0xFF5C6BC0,
      0xFF29B6F6,
      0xFF26A69A,
      0xFF66BB6A,
      0xFFFFCA28,
      0xFFFFA726,
      0xFF8D6E63,
      0xFF78909C,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('颜色（可选）'),
        const SizedBox(height: 8),
        Wrap(
          children: [
            ...palette.map(
              (c) => InkWell(
                onTap: () => onChanged(c),
                child: Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(right: 8, bottom: 8),
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color == c ? Colors.black : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: color == c
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
            ),
            TextButton(
              onPressed: () => onChanged(null),
              child: const Text('清除'),
            ),
          ],
        ),
      ],
    );
  }
}

