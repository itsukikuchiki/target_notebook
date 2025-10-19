import 'package:flutter/material.dart';

class ReflectionEditPage extends StatelessWidget {
  const ReflectionEditPage({super.key});
  static const route = '/reflection/edit';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新增反思'),
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
        child: Text('TODO: 反思编辑表单'),
      ),
    );
  }
}

