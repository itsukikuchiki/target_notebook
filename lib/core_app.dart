import 'package:flutter/material.dart';
import 'main_screen.dart'; // ✅ 新增导入

class CoreApp extends StatelessWidget {
  const CoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '目標手帳',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const MainScreen(), // 现在能解析到
    );
  }
}

