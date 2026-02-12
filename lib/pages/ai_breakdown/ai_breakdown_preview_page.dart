// lib/pages/ai_breakdown/ai_breakdown_preview_page.dart
import 'package:flutter/material.dart';

import '../../models/ai_breakdown_models.dart';

class AiBreakdownPreviewPage extends StatefulWidget {
  final AiBreakdownResult initial;

  const AiBreakdownPreviewPage({super.key, required this.initial});

  @override
  State<AiBreakdownPreviewPage> createState() => _AiBreakdownPreviewPageState();
}

class _AiBreakdownPreviewPageState extends State<AiBreakdownPreviewPage> {
  late AiBreakdownResult draft;

  @override
  void initState() {
    super.initState();
    // 深拷贝（避免直接改引用）
    draft = AiBreakdownResult.fromJson(widget.initial.toJson());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 分解预览'),
        actions: [
          TextButton(
            key: const Key('ai_breakdown_save'),
            onPressed: () => Navigator.pop(context, draft),
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: draft.subGoals.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) {
          final sg = draft.subGoals[i];
          return Card(
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: sg.title,
                        decoration: const InputDecoration(
                          labelText: '子目标标题',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => sg.title = v.trim().isEmpty ? sg.title : v.trim(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: '删除子目标',
                      onPressed: () {
                        setState(() => draft.subGoals.removeAt(i));
                      },
                      icon: const Icon(Icons.delete_outline),
                    )
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: sg.description ?? '',
                        decoration: const InputDecoration(
                          labelText: '说明（可选）',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => sg.description = v.trim(),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    SizedBox(
                      width: 140,
                      child: DropdownButtonFormField<int>(
                        value: sg.priority.clamp(1, 5),
                        decoration: const InputDecoration(
                          labelText: '优先度',
                          border: OutlineInputBorder(),
                        ),
                        items: const [1, 2, 3, 4, 5].map((p) {
                          return DropdownMenuItem(value: p, child: Text('P$p'));
                        }).toList(),
                        onChanged: (v) => setState(() => sg.priority = v ?? 3),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '预计 ${sg.estimateDays} 天 · 任务 ${sg.tasks.length} 条',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),

                  ...sg.tasks.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final t = entry.value;
                    return _TaskEditorRow(
                      task: t,
                      onDelete: () => setState(() => sg.tasks.removeAt(idx)),
                      onChanged: () => setState(() {}),
                    );
                  }),

                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: Key('ai_breakdown_add_task_$i'),
                      onPressed: () {
                        setState(() {
                          sg.tasks.add(
                            AiTaskDraft(title: '新任务', minutes: 45, dueInDays: 2, priority: 3),
                          );
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('新增任务'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TaskEditorRow extends StatelessWidget {
  final AiTaskDraft task;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const _TaskEditorRow({
    required this.task,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              initialValue: task.title,
              decoration: const InputDecoration(
                labelText: '任务标题',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                final vv = v.trim();
                if (vv.isNotEmpty) task.title = vv;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: DropdownButtonFormField<int>(
              value: task.minutes.clamp(15, 240),
              decoration: const InputDecoration(
                labelText: '分钟',
                border: OutlineInputBorder(),
              ),
              items: const [15, 30, 45, 60, 90, 120].map((m) {
                return DropdownMenuItem(value: m, child: Text('$m'));
              }).toList(),
              onChanged: (v) {
                task.minutes = v ?? task.minutes;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: DropdownButtonFormField<int>(
              value: task.priority.clamp(1, 5),
              decoration: const InputDecoration(
                labelText: 'P',
                border: OutlineInputBorder(),
              ),
              items: const [1, 2, 3, 4, 5].map((p) {
                return DropdownMenuItem(value: p, child: Text('$p'));
              }).toList(),
              onChanged: (v) {
                task.priority = v ?? task.priority;
                onChanged();
              },
            ),
          ),
          IconButton(onPressed: onDelete, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }
}

