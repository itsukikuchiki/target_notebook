// lib/pages/ai_breakdown/ai_breakdown_input_sheet.dart
import 'package:flutter/material.dart';

import '../../models/goal.dart';

class AiBreakdownInput {
  final String description;
  final DateTime? deadline;
  final int weeklyHours;

  AiBreakdownInput({
    required this.description,
    required this.deadline,
    required this.weeklyHours,
  });
}

class AiBreakdownInputSheet extends StatefulWidget {
  final Goal goal;

  const AiBreakdownInputSheet({super.key, required this.goal});

  @override
  State<AiBreakdownInputSheet> createState() => _AiBreakdownInputSheetState();
}

class _AiBreakdownInputSheetState extends State<AiBreakdownInputSheet> {
  late final TextEditingController _desc;
  DateTime? _deadline;
  int _weeklyHours = 5;

  @override
  void initState() {
    super.initState();
    _desc = TextEditingController(text: widget.goal.description ?? '');
    _deadline = widget.goal.dueDate;
  }

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            const Icon(Icons.auto_awesome),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'AI 目标分解：${widget.goal.title}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
          const SizedBox(height: 12),

          TextField(
            controller: _desc,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '目标补充说明（可选）',
              hintText: '例如：希望两个月内通过；每天可投入 1 小时；薄弱章节是…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          Row(children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 10),
                    initialDate: _deadline ?? now,
                  );
                  if (picked != null) setState(() => _deadline = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '截止日期（可选）',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _deadline == null
                        ? '未设置'
                        : '${_deadline!.year}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              child: DropdownButtonFormField<int>(
                value: _weeklyHours,
                decoration: const InputDecoration(
                  labelText: '每周小时',
                  border: OutlineInputBorder(),
                ),
                items: const [2, 3, 5, 7, 10, 14].map((h) {
                  return DropdownMenuItem(value: h, child: Text('$h h'));
                }).toList(),
                onChanged: (v) => setState(() => _weeklyHours = v ?? 5),
              ),
            )
          ]),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('ai_breakdown_cancel'),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  key: const Key('ai_breakdown_generate'),
                  onPressed: () {
                    Navigator.pop(
                      context,
                      AiBreakdownInput(
                        description: _desc.text.trim(),
                        deadline: _deadline,
                        weeklyHours: _weeklyHours,
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('生成'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

