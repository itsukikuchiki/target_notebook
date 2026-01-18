import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/sub_goal.dart';
import '../../providers/sub_goal_provider.dart';

class SubGoalEditPage extends StatefulWidget {
  const SubGoalEditPage({super.key});
  static const route = '/subgoal/edit';

  @override
  State<SubGoalEditPage> createState() => _SubGoalEditPageState();
}

/// 路由参数：
/// - goalId: 必传（子目标属于哪个 Goal）
/// - subGoalKey: 可选（传了则进入编辑模式）
class SubGoalEditArgs {
  final int goalId;
  final int? subGoalKey;

  const SubGoalEditArgs({
    required this.goalId,
    this.subGoalKey,
  });
}

class _SubGoalEditPageState extends State<SubGoalEditPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;

  int _priority = 3; // 1..5
  int _orderIndex = 0;
  int? _color; // ARGB int

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

  void _initFromArgs(SubGoalEditArgs args) {
    if (_inited) return;
    _inited = true;

    if (args.subGoalKey == null) return;

    final p = context.read<SubGoalProvider>();
    final s = p.getByKey(args.subGoalKey!);
    if (s == null) return;

    _titleCtrl.text = s.title;
    _descCtrl.text = s.description ?? '';
    _priority = s.priority;
    _orderIndex = s.orderIndex;
    _color = s.color;
  }

  Future<void> _save(SubGoalEditArgs args) async {
    if (_saving) return;

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _saving = true);

    try {
      final provider = context.read<SubGoalProvider>();

      final patch = SubGoal(
        goalId: args.goalId,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        orderIndex: _orderIndex,
        priority: _priority,
        color: _color,
      );

      if (args.subGoalKey == null) {
        await provider.addSubGoal(patch);
      } else {
        await provider.updateSubGoal(args.subGoalKey!, patch);
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
    final args = ModalRoute.of(context)?.settings.arguments;

    // 为了避免你路由传错导致白屏，这里做一个兜底
    if (args is! SubGoalEditArgs) {
      return Scaffold(
        appBar: AppBar(title: const Text('子目标')),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            '缺少路由参数：SubGoalEditArgs(goalId: ..., subGoalKey?: ...)\n'
            '请从 My Journey 传入 goalId。',
          ),
        ),
      );
    }

    _initFromArgs(args);

    final isEdit = args.subGoalKey != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '编辑子目标' : '新增子目标'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _save(args),
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
                  labelText: '标题',
                  hintText: '例如：完成收费功能',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请输入标题';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: '说明（可选）',
                  hintText: '一句话描述子目标内容',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Priority
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
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _priority = v);
                    },
                  ),
                  const Spacer(),
                  const Text('顺序'),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 90,
                    child: TextFormField(
                      initialValue: _orderIndex.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: '0',
                      ),
                      onChanged: (v) {
                        final n = int.tryParse(v) ?? 0;
                        _orderIndex = n;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Color picker (simple)
              _ColorRow(
                color: _color,
                onChanged: (c) => setState(() => _color = c),
              ),

              const SizedBox(height: 24),
              Text(
                '提示：\n'
                '- color 不选时，将默认继承 Goal 的颜色\n'
                '- priority 用于 My Journey 和日历排序',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 简易颜色选择（不引入第三方库）
class _ColorRow extends StatelessWidget {
  final int? color;
  final ValueChanged<int?> onChanged;

  const _ColorRow({
    required this.color,
    required this.onChanged,
  });

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

    Widget chip(int c) {
      final selected = color == c;
      return InkWell(
        onTap: () => onChanged(c),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Color(c),
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Colors.black : Colors.transparent,
              width: 2,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : null,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('颜色（可选）'),
        const SizedBox(height: 8),
        Wrap(
          children: [
            ...palette.map(chip),
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


