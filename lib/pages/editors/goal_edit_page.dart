import 'package:flutter/material.dart';

class GoalEditPage extends StatelessWidget {
  const GoalEditPage({super.key, this.goalId});
  static const route = '/goal/edit';

  final int? goalId; // 未来可用于加载/保存

  @override
  Widget build(BuildContext context) {
    final idStr = (goalId == null) ? '' : '（#${goalId!}）';
    return Scaffold(
      appBar: AppBar(
        title: Text('新增目标$idStr'),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已保存（演示占位，不落库）')),
              );
              Navigator.of(context).pop();
            },
            child: const Text('保存'),
          ),
        ],
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Text('TODO: 目标编辑表单'),
      ),
    );
  }
}

