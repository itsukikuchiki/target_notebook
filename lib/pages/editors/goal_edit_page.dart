import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/goal.dart';
import '../../providers/goal_provider.dart';
import '../../widgets/color_picker.dart';

class GoalEditPage extends StatefulWidget {
  const GoalEditPage({super.key, this.goalId});
  static const route = '/goal/edit';

  final int? goalId; // null = 新增，非 null = 编辑

  @override
  State<GoalEditPage> createState() => _GoalEditPageState();
}

class _GoalEditPageState extends State<GoalEditPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;

  int _priority = 3;
  int? _color; // int?，null = 继承 / 默认

  bool _inited = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _descCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _initFromExisting() {
    if (_inited) return;
    _inited = true;

    final goalId = widget.goalId;
    if (goalId == null) return;

    final provider = context.read<GoalProvider>();
    final g = provider.getByKey(goalId);
    if (g == null) return;

    _titleCtrl.text = g.title;
    _descCtrl.text = g.description ?? '';
    _priority = g.priority;
    _color = g.color;
  }

  Future<void> _save() async {
    if (_saving) return;
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _saving = true);

    try {
      final provider = context.read<GoalProvider>();

      final title = _titleCtrl.text.trim();
      final desc =
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();

      final goal = Goal(
        title: title,
        description: desc,
        priority: _priority,
        color: _color,
      );

      if (widget.goalId == null) {
        // 新增
        await provider.addGoal(goal);
      } else {
        // 编辑
        await provider.updateGoal(widget.goalId!, goal);
      }

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

  @override
  Widget build(BuildContext context) {
    _initFromExisting();

    final isEdit = widget.goalId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '编辑目标' : '新增目标'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const Text('保存中...')
                : const Text('保存'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // ---------- Title ----------
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: '目标名称',
                  hintText: '例如：通过 FP2 / 完成 App 上线',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '请输入目标名称' : null,
              ),
              const SizedBox(height: 16),

              // ---------- Description ----------
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: '目标说明（可选）',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // ---------- Priority ----------
              Row(
                children: [
                  const Text('优先度'),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _priority,
                    items: const [1, 2, 3, 4, 5]
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text('P$v'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _priority = v ?? 3),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ---------- Color Picker ----------
              ColorPicker(
                selected: _color,
                onChanged: (c) => setState(() => _color = c),
              ),

              const SizedBox(height: 24),
              Text(
                '说明：\n'
                '- 颜色用于日历 / 目标树 / 任务联动展示\n'
                '- 未选择颜色时，系统会自动分配默认色\n'
                '- 子目标 / 任务可继承该颜色',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

