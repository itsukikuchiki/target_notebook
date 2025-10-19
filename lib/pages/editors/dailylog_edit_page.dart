import 'package:flutter/material.dart';

class DailyLogEditPage extends StatelessWidget {
  const DailyLogEditPage({super.key});
  static const route = '/dailylog/edit';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新增打卡'),
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
        child: Text('TODO: 打卡表单'),
      ),
    );
  }
}

