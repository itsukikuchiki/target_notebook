import 'package:flutter/material.dart';

class NewTaskDialog extends StatefulWidget {
  final Future<void> Function(String title) onSubmit;
  const NewTaskDialog({required this.onSubmit, super.key});

  @override
  State<NewTaskDialog> createState() => _NewTaskDialogState();
}

class _NewTaskDialogState extends State<NewTaskDialog> {
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新增任务'),
      content: TextField(
        controller: _ctrl,
        decoration: const InputDecoration(
          hintText: '输入任务名称',
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          key: const Key('dialog.addtask.submit'),
          onPressed: _saving
              ? null
              : () async {
                  final text = _ctrl.text.trim();
                  if (text.isEmpty) return;

                  setState(() => _saving = true);
                  try {
                    await widget.onSubmit(text);
                    if (context.mounted) Navigator.pop(context);
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

