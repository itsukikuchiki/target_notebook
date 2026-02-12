import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/goal.dart';
import '../../providers/goal_provider.dart';
import '../../widgets/color_picker.dart';

class GoalEditPage extends StatefulWidget {
  const GoalEditPage({super.key});
  static const route = '/goal/edit';

  @override
  State<GoalEditPage> createState() => _GoalEditPageState();
}

class _GoalEditPageState extends State<GoalEditPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;

  int _priority = 3;
  int? _color;

  int? _goalKey; // ✅ 从路由 arguments 获取（null=新增）
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

  void _initFromRouteArgsIfNeeded() {
    if (_inited) return;
    _inited = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    // 兼容：args 可能是 int / String / null
    int? key;
    if (args is int) key = args;
    if (args is String) key = int.tryParse(args);

    _goalKey = key;
    if (_goalKey == null) return; // 新增模式

    final provider = context.read<GoalProvider>();
    final g = provider.getByKey(_goalKey!);
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
      final desc = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();

      final patch = Goal(
        title: title,
        description: desc,
        priority: _priority,
        color: _color,
      );

      if (_goalKey == null) {
        // 新增
        await provider.addGoal(patch);
      } else {
        // 编辑
        await provider.updateGoal(_goalKey!, patch);
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

  Future<void> _delete() async {
    final key = _goalKey;
    if (key == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除目标？'),
        content: const Text('删除后无法恢复（仅删除目标本身，关联任务/子目标后续可再做级联删除）。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final provider = context.read<GoalProvider>();
      await provider.deleteGoal(key);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _initFromRouteArgsIfNeeded();

    final isEdit = _goalKey != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '编辑目标' : '新增目标'),
        actions: [
          if (isEdit)
            IconButton(
              tooltip: '删除',
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
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
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: '目标说明（可选）',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  const Text('优先度'),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _priority,
                    items: const [1, 2, 3, 4, 5]
                        .map((v) => DropdownMenuItem(
                              value: v,
                              child: Text('P$v'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _priority = v ?? 3),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              ColorPicker(
                selected: _color,
                onChanged: (c) => setState(() => _color = c),
              ),

              const SizedBox(height: 24),
              Text(
                '说明：\n'
                '- 颜色用于日历 / 目标树 / 任务联动展示\n'
                '- 未选择颜色时，系统会自动分配默认色（effectiveColor）\n'
                '- 子目标 / 任务可继承该颜色（后续在 12/15 联动里接入）',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

