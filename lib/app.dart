import 'package:flutter/material.dart';

import 'pages/daily_page.dart';
import 'pages/insight_page.dart';
import 'pages/reflection_page.dart';
import 'widgets/plus_panel.dart';

/// 对外暴露的根 Widget，供 main.dart 和测试使用。
///
/// 注意：这个 Widget **不再负责 Hive / Provider 初始化**，
/// 只构建 MaterialApp + 底部导航；
/// Provider 由外层 MultiProvider 注入（参考 main.dart / 各测试）。
class TargetNotebookApp extends StatelessWidget {
  const TargetNotebookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Target Notebook',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const _MainScaffold(),
    );
  }
}

class _MainScaffold extends StatefulWidget {
  const _MainScaffold();

  @override
  State<_MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<_MainScaffold> {
  int _index = 0;

  final _pages = const [
    DailyPage(),
    InsightPage(),
    ReflectionPage(),
    PlusPanel(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_today),
            label: 'Daily',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart),
            label: 'Insight',
          ),
          NavigationDestination(
            icon: Icon(Icons.book),
            label: 'Reflection',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            label: 'Plus',
          ),
        ],
        onDestinationSelected: (i) => setState(() => _index = i),
      ),
    );
  }
}

